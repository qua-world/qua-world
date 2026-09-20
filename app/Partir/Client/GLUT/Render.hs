-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Client.GLUT.Render
Description : Draw a loaded 'Mesh' through the core-profile OpenGL pipeline

The minimum needed to see an asset on screen: each 'Primitive' uploaded once
into a vertex array object, and a frame that sets a camera and issues one draw
call per primitive.

Everything here is core profile. @renderPrimitive@, @vertex@, and the
@GLU.perspective@ \/ @GLU.lookAt@ matrix stack are absent from a core context,
so transforms come from "Linear" and reach the shader as a uniform.

Only geometry is read from the asset. A material binding selects nothing yet:
every primitive draws in one placeholder color.
-}
module Partir.Client.GLUT.Render (
  Renderer,
  upload,
  draw,

  -- * Viewpoint
  camera,
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
import Linear.Matrix (M44, (!*!))
import Linear.Projection (lookAt, perspective)
import Linear.V3 (V3 (..))

import Partir.Asset (Mesh (..), Primitive (..))

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

{- | Compile the shader program and copy every primitive into GPU buffers.
Call once: a 'Renderer' holds names that stay valid for the life of the
context, and 'draw' allocates nothing.
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

{- | How many elements one draw call issues: the indices when the primitive
has them, otherwise its vertices.
-}
elementCount :: Primitive -> GL.GLsizei
elementCount prim
  | Vector.null indices = fromIntegral (Vector.length (primitivePositions prim))
  | otherwise = fromIntegral (Vector.length indices)
 where
  indices = primitiveIndices prim

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

-- | Record the triangle indices in the bound vertex array object.
bindIndices :: Vector.Vector Word32 -> IO ()
bindIndices indices =
  fillBuffer GL.ElementArrayBuffer (sizeOf (undefined :: GL.GLuint)) values
 where
  values = map fromIntegral (Vector.toList indices) :: [GL.GLuint]

-- | Copy three-component vectors into a fresh buffer feeding one attribute.
bindVectorAttribute :: GL.AttribLocation -> Vector.Vector (V3 Float) -> IO ()
bindVectorAttribute location values = do
  fillBuffer GL.ArrayBuffer (sizeOf (undefined :: GL.GLfloat)) components
  GL.vertexAttribPointer location
    $= (GL.ToFloat, GL.VertexArrayDescriptor 3 GL.Float 0 nullPtr)
  GL.vertexAttribArray location $= GL.Enabled
 where
  components = concatMap toList (Vector.toList values) :: [GL.GLfloat]

{- | Fill a fresh buffer object, bound to the given target, from a list. The
buffer stays bound, which is what records it in the bound vertex array
object.

The caller passes the size of one element. Deriving it here instead would put
the element type in a signature this module cannot write under Haskell2010,
and the repository adds no language extensions.
-}
fillBuffer :: Storable a => GL.BufferTarget -> Int -> [a] -> IO ()
fillBuffer bufferTarget elementBytes values = do
  buffer <- GL.genObjectName
  GL.bindBuffer bufferTarget $= Just buffer
  withArray values $ \ptr ->
    GL.bufferData bufferTarget
      $= (fromIntegral (length values * elementBytes), ptr, GL.StaticDraw)

{- | Clear and draw the mesh in front of a fixed camera, sized to the window.
The caller presents the frame.
-}
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

{- | The transform from model space to clip space, for a window of the given
size: a fixed viewpoint, and a projection matched to the window's aspect
ratio.

Pure, so what the client points at is checkable without a context.
-}
camera :: GL.Size -> M44 Float
camera (GL.Size width height) =
  perspective verticalFieldOfView aspect nearPlane farPlane !*! lookAt eye target up
 where
  aspect = fromIntegral width / fromIntegral (max 1 height)

{- | Where the client watches the world from. The viewpoint sits off all three
axes so an asset reads as a solid rather than as its own silhouette.
-}
eye, target, up :: V3 Float
eye = V3 2.2 1.6 2.6
target = V3 0 0 0
up = V3 0 1 0

-- | The visible depth range, and how much of the world fits across it.
verticalFieldOfView, nearPlane, farPlane :: Float
verticalFieldOfView = pi / 4
nearPlane = 0.1
farPlane = 100

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

-- A fixed headlamp rather than a light in the world: enough shading to read
-- the asset's shape on screen, and nothing the scene has to own yet.
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
