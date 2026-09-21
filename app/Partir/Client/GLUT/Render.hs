-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Client.GLUT.Render
Description : Draw a loaded 'Mesh' through the core-profile OpenGL pipeline

Each 'Primitive' is uploaded once into a vertex array object, and every frame
issues one draw call per primitive.

The context is core profile, which has no matrix stack, so transforms are
"Linear" matrices reaching the shader as uniforms.

Only geometry is read from the asset. A material binding selects nothing:
every primitive draws in one placeholder color.

A 'Sprite' draws over that scene as a screen-space icon, one frame of the
sheet in the window's top-left corner. It takes no part in the camera: its
corners are already in clip space.
-}
module Partir.Client.GLUT.Render (
  Renderer,
  upload,
  draw,
)
where

import Control.Monad (unless, when)
import qualified Data.ByteString.Char8 as ByteString
import Data.Foldable (toList, traverse_)
import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as Storable
import Data.Word (Word32)
import Foreign.Marshal.Array (withArray)
import Foreign.Ptr (nullPtr)
import Foreign.Storable (Storable, sizeOf)
import Graphics.Rendering.OpenGL (($=))
import qualified Graphics.Rendering.OpenGL as GL
import Linear.Matrix (M44)
import Linear.V3 (V3 (..))

import Partir.Asset (Frame, Mesh (..), Primitive (..), Sprite (..))
import Partir.Client.GLUT.View (
  Bounds (..),
  camera,
  elementCount,
  frameBounds,
  overlayBounds,
 )

-- | A mesh resident on the GPU, ready to draw.
data Renderer = Renderer
  { rendererProgram :: GL.Program
  , rendererDraws :: [Draw]
  , rendererOverlay :: Maybe Overlay
  -- ^ Absent when the sheet holds no frame to show.
  }

{- | The icon's own program, quad, and sheet, with the frame it shows already
reduced to the bounds that select it. Drawing one reads no 'Sprite'.
-}
data Overlay = Overlay
  { overlayProgram :: GL.Program
  , overlayArray :: GL.VertexArrayObject
  , overlayTexture :: GL.TextureObject
  , overlaySheetBounds :: Bounds
  }

{- | One primitive's vertex array and the call that draws it. Indices are
optional in the asset, so the count means elements or vertices accordingly.
-}
data Draw = Draw
  { drawArray :: GL.VertexArrayObject
  , drawCount :: GL.GLsizei
  , drawIndexed :: Bool
  }

positionAttribute :: GL.AttribLocation
positionAttribute = GL.AttribLocation 0

normalAttribute :: GL.AttribLocation
normalAttribute = GL.AttribLocation 1

{- | The overlay quad's attribute. It shares a location with
'positionAttribute' because each program binds its own.
-}
cornerAttribute :: GL.AttribLocation
cornerAttribute = GL.AttribLocation 0

{- | Call once per context: a 'Renderer' holds names valid for that context's
lifetime, and 'draw' allocates nothing.
-}
upload :: Mesh -> Sprite -> IO Renderer
upload mesh sprite = do
  GL.depthFunc $= sceneDepthFunc
  program <- buildProgram vertexSource fragmentSource
  draws <- traverse uploadPrimitive (meshPrimitives mesh)
  overlay <- traverse (uploadOverlay sprite) (spriteFrames sprite Vector.!? 0)
  pure
    Renderer
      { rendererProgram = program
      , rendererDraws = draws
      , rendererOverlay = overlay
      }

uploadPrimitive :: Primitive -> IO Draw
uploadPrimitive prim = do
  vao <- GL.genObjectName
  GL.bindVertexArrayObject $= Just vao

  bindVectorAttribute positionAttribute (primitivePositions prim)
  bindNormals (primitiveNormals prim)
  when indexed $ bindIndices (primitiveIndices prim)

  GL.bindVertexArrayObject $= Nothing
  pure Draw{drawArray = vao, drawCount = elementCount prim, drawIndexed = indexed}
 where
  indexed = not (Vector.null (primitiveIndices prim))

{- | Feed the normal attribute. An asset that ships no normals leaves the
array disabled, and the shader then reads one generic value for every vertex.
Lighting it evenly beats reading an undefined attribute.
-}
bindNormals :: Vector.Vector (V3 Float) -> IO ()
bindNormals normals
  | Vector.null normals = GL.vertexAttrib GL.ToFloat normalAttribute facingViewer
  | otherwise = bindVectorAttribute normalAttribute normals
 where
  facingViewer = GL.Vertex3 (0 :: GL.GLfloat) 0 1

bindIndices :: Vector.Vector Word32 -> IO ()
bindIndices indices =
  fillBuffer GL.ElementArrayBuffer (sizeOf (undefined :: GL.GLuint)) values
 where
  values = map fromIntegral (Vector.toList indices) :: [GL.GLuint]

bindVectorAttribute :: GL.AttribLocation -> Vector.Vector (V3 Float) -> IO ()
bindVectorAttribute location =
  bindAttribute location 3 . concatMap toList . Vector.toList

-- | Feed one attribute from a flat run of components, given how many a vertex takes.
bindAttribute :: GL.AttribLocation -> GL.NumComponents -> [GL.GLfloat] -> IO ()
bindAttribute location components values = do
  fillBuffer GL.ArrayBuffer (sizeOf (undefined :: GL.GLfloat)) values
  GL.vertexAttribPointer location
    $= (GL.ToFloat, GL.VertexArrayDescriptor components GL.Float 0 nullPtr)
  GL.vertexAttribArray location $= GL.Enabled

{- | Fill a fresh buffer object from a list, leaving it bound, which is what
records it in the bound vertex array object.

The element size is a parameter because deriving it from the list needs
@ScopedTypeVariables@, and nothing here enables an extension.
-}
fillBuffer :: Storable a => GL.BufferTarget -> Int -> [a] -> IO ()
fillBuffer bufferTarget elementBytes values = do
  buffer <- GL.genObjectName
  GL.bindBuffer bufferTarget $= Just buffer
  withArray values $ \ptr ->
    GL.bufferData bufferTarget
      $= (fromIntegral (length values * elementBytes), ptr, GL.StaticDraw)

{- | Upload the icon: its own program over a unit square, and the whole sheet
as one texture that the frame's bounds select from.
-}
uploadOverlay :: Sprite -> Frame -> IO Overlay
uploadOverlay sprite frame = do
  program <- buildProgram overlayVertexSource overlayFragmentSource

  vao <- GL.genObjectName
  GL.bindVertexArrayObject $= Just vao
  bindAttribute cornerAttribute 2 unitSquare
  GL.bindVertexArrayObject $= Nothing

  texture <- uploadSheet sprite
  pure
    Overlay
      { overlayProgram = program
      , overlayArray = vao
      , overlayTexture = texture
      , overlaySheetBounds = frameBounds sprite frame
      }

{- | The quad's corners, as the fractions of its bounds the vertex shader
interpolates between, wound as a triangle strip.
-}
unitSquare :: [GL.GLfloat]
unitSquare = [0, 0, 0, 1, 1, 0, 1, 1]

unitSquareCorners :: GL.GLsizei
unitSquareCorners = fromIntegral (length unitSquare `div` 2)

-- | The depth test the scene draws under, which 'drawOverlay' suspends.
sceneDepthFunc :: Maybe GL.ComparisonFunction
sceneDepthFunc = Just GL.Less

uploadSheet :: Sprite -> IO GL.TextureObject
uploadSheet sprite = do
  texture <- GL.genObjectName
  GL.textureBinding GL.Texture2D $= Just texture

  -- Sprite art is drawn a texel at a time, so a magnified texel stays a
  -- square rather than blurring into its neighbours.
  GL.textureFilter GL.Texture2D $= ((GL.Nearest, Nothing), GL.Nearest)

  -- A frame reaching the sheet's edge samples its own last texel rather than
  -- wrapping to the frame opposite.
  GL.textureWrapMode GL.Texture2D GL.S $= (GL.Repeated, GL.ClampToEdge)
  GL.textureWrapMode GL.Texture2D GL.T $= (GL.Repeated, GL.ClampToEdge)

  Storable.unsafeWith (spritePixels sprite) $ \pixels ->
    GL.texImage2D
      GL.Texture2D
      GL.NoProxy
      0
      GL.RGBA8
      (GL.TextureSize2D (fromIntegral (spriteWidth sprite)) (fromIntegral (spriteHeight sprite)))
      0
      (GL.PixelData GL.RGBA GL.UnsignedByte pixels)
  pure texture

-- | Draws one frame. The caller presents it.
draw :: Renderer -> GL.Size -> IO ()
draw renderer size = do
  GL.viewport $= (GL.Position 0 0, size)
  GL.clear [GL.ColorBuffer, GL.DepthBuffer]
  GL.currentProgram $= Just (rendererProgram renderer)
  setMatrix (rendererProgram renderer) "modelViewProjection" (camera size)

  traverse_ issue (rendererDraws renderer)
  GL.bindVertexArrayObject $= Nothing

  traverse_ (drawOverlay size) (rendererOverlay renderer)
 where
  issue d = do
    GL.bindVertexArrayObject $= Just (drawArray d)
    if drawIndexed d
      then GL.drawElements GL.Triangles (drawCount d) GL.UnsignedInt nullPtr
      else GL.drawArrays GL.Triangles 0 (drawCount d)

{- | Draw the icon over the scene: in front of whatever depth the scene left,
and blended so the transparent margin around the frame's art lets it through.
-}
drawOverlay :: GL.Size -> Overlay -> IO ()
drawOverlay size overlay = do
  GL.depthFunc $= Nothing
  GL.blend $= GL.Enabled
  GL.blendFunc $= (GL.SrcAlpha, GL.OneMinusSrcAlpha)

  GL.currentProgram $= Just program
  setBounds program "overlayBounds" (overlayBounds size)
  setBounds program "frameBounds" (overlaySheetBounds overlay)

  GL.activeTexture $= GL.TextureUnit 0
  GL.textureBinding GL.Texture2D $= Just (overlayTexture overlay)
  setUniform program "sheet" (0 :: GL.GLint)

  GL.bindVertexArrayObject $= Just (overlayArray overlay)
  GL.drawArrays GL.TriangleStrip 0 unitSquareCorners
  GL.bindVertexArrayObject $= Nothing

  GL.blend $= GL.Disabled
  GL.depthFunc $= sceneDepthFunc
 where
  program = overlayProgram overlay

-- | Assign a program's uniform by name, whatever shape it takes.
setUniform :: GL.Uniform a => GL.Program -> String -> a -> IO ()
setUniform program name value = do
  location <- GL.uniformLocation program name
  GL.uniform location $= value

-- | Upload a rectangle to a @vec4@ uniform.
setBounds :: GL.Program -> String -> Bounds -> IO ()
setBounds program name bounds = setUniform program name corners
 where
  corners =
    GL.Vertex4
      (boundsLeft bounds)
      (boundsTop bounds)
      (boundsRight bounds)
      (boundsBottom bounds)

{- | Upload a "Linear" matrix to a @mat4@ uniform. @linear@ nests rows, which
is what 'GL.RowMajor' names, so the flattened elements transfer as they are.
-}
setMatrix :: GL.Program -> String -> M44 Float -> IO ()
setMatrix program name matrix =
  setUniform program name
    =<< (GL.newMatrix GL.RowMajor (concatMap toList matrix) :: IO (GL.GLmatrix GL.GLfloat))

buildProgram :: String -> String -> IO GL.Program
buildProgram vertexShader fragmentShader = do
  vertex <- compile GL.VertexShader vertexShader
  fragment <- compile GL.FragmentShader fragmentShader
  program <- GL.createProgram
  traverse_ (GL.attachShader program) [vertex, fragment]
  GL.linkProgram program
  linked <- GL.linkStatus program
  unless linked $ GL.programInfoLog program >>= fail . ("linking the shader program: " ++)
  traverse_ (GL.deleteObjectName :: GL.Shader -> IO ()) [vertex, fragment]
  pure program

compile :: GL.ShaderType -> String -> IO GL.Shader
compile kind source = do
  shader <- GL.createShader kind
  GL.shaderSourceBS shader $= ByteString.pack source
  GL.compileShader shader
  compiled <- GL.compileStatus shader
  unless compiled $ GL.shaderInfoLog shader >>= fail . ((show kind ++ ": ") ++)
  pure shader

vertexSource :: String
vertexSource =
  unlines
    [ "#version 330 core"
    , "layout (location = 0) in vec3 position;"
    , "layout (location = 1) in vec3 normal;"
    , "uniform mat4 modelViewProjection;"
    , "out vec3 shadingNormal;"
    , "void main() {"
    , "  shadingNormal = normal;"
    , "  gl_Position = modelViewProjection * vec4(position, 1.0);"
    , "}"
    ]

-- The light is fixed to the viewer, not placed in the scene.
fragmentSource :: String
fragmentSource =
  unlines
    [ "#version 330 core"
    , "in vec3 shadingNormal;"
    , "out vec4 fragmentColor;"
    , "void main() {"
    , "  vec3 baseColor = vec3(0.6, 0.7, 0.9);"
    , "  vec3 toLight = normalize(vec3(0.4, 0.8, 0.6));"
    , "  float diffuse = max(dot(normalize(shadingNormal), toLight), 0.0);"
    , "  fragmentColor = vec4(baseColor * (0.25 + 0.75 * diffuse), 1.0);"
    , "}"
    ]

-- Both rectangles arrive as (left, top) in xy and (right, bottom) in zw, so
-- one corner in the unit square interpolates position and sheet coordinate
-- alike.
overlayVertexSource :: String
overlayVertexSource =
  unlines
    [ "#version 330 core"
    , "layout (location = 0) in vec2 corner;"
    , "uniform vec4 overlayBounds;"
    , "uniform vec4 frameBounds;"
    , "out vec2 sheetCoordinate;"
    , "void main() {"
    , "  sheetCoordinate = mix(frameBounds.xy, frameBounds.zw, corner);"
    , "  gl_Position = vec4(mix(overlayBounds.xy, overlayBounds.zw, corner), 0.0, 1.0);"
    , "}"
    ]

overlayFragmentSource :: String
overlayFragmentSource =
  unlines
    [ "#version 330 core"
    , "in vec2 sheetCoordinate;"
    , "uniform sampler2D sheet;"
    , "out vec4 fragmentColor;"
    , "void main() {"
    , "  fragmentColor = texture(sheet, sheetCoordinate);"
    , "}"
    ]
