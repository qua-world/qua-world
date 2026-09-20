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
import Data.Word (Word32)
import Foreign.Marshal.Array (withArray)
import Foreign.Ptr (nullPtr)
import Foreign.Storable (Storable, sizeOf)
import Graphics.Rendering.OpenGL (($=))
import qualified Graphics.Rendering.OpenGL as GL
import Linear.Matrix (M44)
import Linear.V3 (V3 (..))

import Partir.Asset (Mesh (..), Primitive (..))
import Partir.Client.GLUT.View (camera, elementCount)

-- | A mesh resident on the GPU, ready to draw.
data Renderer = Renderer
  { rendererProgram :: GL.Program
  , rendererDraws :: [Draw]
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

{- | Call once per context: a 'Renderer' holds names valid for that context's
lifetime, and 'draw' allocates nothing.
-}
upload :: Mesh -> IO Renderer
upload mesh = do
  GL.depthFunc $= Just GL.Less
  program <- buildProgram
  draws <- traverse uploadPrimitive (meshPrimitives mesh)
  pure Renderer{rendererProgram = program, rendererDraws = draws}

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
bindVectorAttribute location values = do
  fillBuffer GL.ArrayBuffer (sizeOf (undefined :: GL.GLfloat)) components
  GL.vertexAttribPointer location
    $= (GL.ToFloat, GL.VertexArrayDescriptor 3 GL.Float 0 nullPtr)
  GL.vertexAttribArray location $= GL.Enabled
 where
  components = concatMap toList (Vector.toList values) :: [GL.GLfloat]

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

-- | Draws one frame. The caller presents it.
draw :: Renderer -> GL.Size -> IO ()
draw renderer size = do
  GL.viewport $= (GL.Position 0 0, size)
  GL.clear [GL.ColorBuffer, GL.DepthBuffer]
  GL.currentProgram $= Just (rendererProgram renderer)
  setMatrix (rendererProgram renderer) "modelViewProjection" (camera size)

  traverse_ issue (rendererDraws renderer)
  GL.bindVertexArrayObject $= Nothing
 where
  issue d = do
    GL.bindVertexArrayObject $= Just (drawArray d)
    if drawIndexed d
      then GL.drawElements GL.Triangles (drawCount d) GL.UnsignedInt nullPtr
      else GL.drawArrays GL.Triangles 0 (drawCount d)

{- | Upload a "Linear" matrix to a @mat4@ uniform. @linear@ nests rows, which
is what 'GL.RowMajor' names, so the flattened elements transfer as they are.
-}
setMatrix :: GL.Program -> String -> M44 Float -> IO ()
setMatrix program name matrix = do
  location <- GL.uniformLocation program name
  value <- GL.newMatrix GL.RowMajor (concatMap toList matrix) :: IO (GL.GLmatrix GL.GLfloat)
  GL.uniform location $= value

buildProgram :: IO GL.Program
buildProgram = do
  vertex <- compile GL.VertexShader vertexSource
  fragment <- compile GL.FragmentShader fragmentSource
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
