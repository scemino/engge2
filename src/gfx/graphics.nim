import ../sys/opengl
import glm
import shader
import glutils
import recti
import image
import texture
import color

type Vertex* = object
  # This is a point in 2D with a color and texture coordinates
  pos*: Vec2f
  color*: Vec4f
  texCoords*: Vec2f
type State = object
  vao, vbo, ebo: uint32
  shader: Shader
  color: Vec3f
  mvp: Mat4f
  cameraSize: Vec2f
  cameraPos: Vec2f
  texture: Texture

var 
  state: State
  vsrc: string = """
#version 330 core
layout (location = 0) in vec2 a_position;
layout (location = 1) in vec4 a_color;
layout (location = 2) in vec2 a_texCoords;
uniform mat4 u_transform;
out vec4 v_color;
out vec2 v_texCoords;
void main() {
  gl_Position = u_transform * vec4(a_position, 0.0, 1.0);
  v_color = a_color;
  v_texCoords = a_texCoords;
}
  """
  fsrc: string = """
#version 330 core
out vec4 FragColor;
in vec4 v_color;
in vec2 v_texCoords;
uniform sampler2D ourTexture;
void main() {
  FragColor = v_color * texture(ourTexture, v_texCoords);
}
  """
  quadIndices = [
    0'u32, 1'u32, 3'u32,
    1'u32, 2'u32, 3'u32
  ]
  emptyImage: Image
  emptyTexture: Texture

proc drawSpriteCore(pos: Vec2f, textRect: Rectf, w, h: float32; color = White)
proc drawPrimitives*(primitivesType: GLenum, vertices: var openArray[Vertex])
proc drawPrimitives*(primitivesType: GLenum, vertices: var openArray[Vertex], indices: var openArray[uint32])

proc newVertex*(x, y, u, v: float32; color = White): Vertex =
  Vertex(pos: vec2(x, y), color: color, texCoords: vec2(u, v))

proc newVertex*(x, y: float32, color: Color): Vertex =
  Vertex(pos: vec2(x, y), color: color, texCoords: vec2(0f))

proc newVertex*(pos, uv: Vec2f, color = White): Vertex =
  Vertex(pos: pos, color: color, texCoords: uv)

proc cameraPos*(pos: Vec2f) =
  state.cameraPos = pos

proc cameraPos*(): Vec2f =
  state.cameraPos

proc camera*(w, h: float32) =
  state.cameraSize = vec2(w, h)
  state.mvp = ortho(0f, w, 0f, h, -1f, 1f)

proc camera*(): Vec2f =
  state.cameraSize

proc bindTexture*(self: Texture) =
  state.texture = self
  glBindTexture(GL_TEXTURE_2D, self.id)

proc noTexture*() =
  state.texture = emptyTexture
  glBindTexture(GL_TEXTURE_2D, emptyTexture.id)

proc gfxShader*(shader: var Shader) =
  state.shader = shader

proc gfxInit*() =
  emptyImage = newImage(1, 1, 4, @[0xFF'u8, 0xFF, 0xFF, 0xFF])
  emptyTexture = newTexture(emptyImage)

  state.shader  = newShader(vsrc, fsrc)
  state.color   = vec3(1f, 1f, 1f)
  state.mvp     = ortho(-1f, 1f, -1f, 1f, -1f, 1f)
  state.texture = emptyTexture

  glGenVertexArrays(1, state.vao.addr)
  glBindVertexArray(state.vao)
  glGenBuffers(1, state.vbo.addr)
  glGenBuffers(1, state.ebo.addr)
  glBindBuffer(GL_ARRAY_BUFFER, state.vbo)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, state.ebo)
  glVertexAttribPointer(0'u32, 2, EGL_FLOAT, false, cfloat.sizeof * 8, nil)
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(1'u32, 4, EGL_FLOAT, false, cfloat.sizeof * 8, cast[pointer](2 * cfloat.sizeof))
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(2'u32, 2, EGL_FLOAT, false, cfloat.sizeof * 8, cast[pointer](6 * cfloat.sizeof))
  glEnableVertexAttribArray(2)
  checkGLError()

proc gfxClear*(color: Color) =
  glClearColor(color.r, color.g, color.b, color.a)
  glClear(GL_COLOR_BUFFER_BIT)

proc gfxDraw*(vertices: var openArray[Vertex], indices: var openArray[uint32]; color = White) =
  drawPrimitives(GL_TRIANGLES, vertices, indices)

proc gfxDrawSprite*(pos: Vec2f, texture: Texture; color = White) =
  texture.bindTexture()
  drawSpriteCore(pos, rect(0f, 0f, 1f, 1f), texture.width.float32, texture.height.float32, color)

proc gfxDrawSprite*(pos: Vec2f, w,h: float, texture: Texture; color = White) =
  texture.bindTexture()
  drawSpriteCore(pos, rect(0f, 0f, 1f, 1f), w.float32, h.float32, color)

proc gfxDrawSprite*(pos: Vec2f, textRect: Rectf, texture: Texture; color = White) =
  let w = textRect.w * texture.width.float32
  let h = textRect.h * texture.height.float32
  texture.bindTexture()
  drawSpriteCore(pos, textRect, w, h, color)

proc gfxDrawLines*(pos: var openArray[Vertex]) =
  drawPrimitives(GL_LINES, pos)

proc drawSpriteCore(pos: Vec2f, textRect: Rectf, w, h: float32; color = White) =
  let l = textRect.x.float32
  let r = (textRect.x + textRect.w).float32
  let t = textRect.y.float32
  let b = (textRect.y + textRect.h).float32
  var vertices = [
    newVertex(pos.x+w, pos.y+h, r, t, color),
    newVertex(pos.x+w, pos.y, r, b, color),
    newVertex(pos.x, pos.y, l, b, color),
    newVertex(pos.x, pos.y+h, l, t, color)
  ]
  gfxDraw(vertices, quadIndices)

proc drawPrimitives*(primitivesType: GLenum, vertices: var openArray[Vertex]) = 
  # set blending
  glEnable(GL_BLEND)
  glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD)
  glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
  checkGLError()

  state.shader.ensureProgramActive:
    state.shader.setUniform("u_transform", state.mvp)

    glBufferData(GL_ARRAY_BUFFER, cint(Vertex.sizeof * vertices.len), vertices[0].addr, GL_STATIC_DRAW)
    glDrawArrays(primitivesType, 0, vertices.len.GLsizei)
    checkGLError()
  
  glDisable(GL_BLEND)

proc drawPrimitives*(primitivesType: GLenum, vertices: var openArray[Vertex], indices: var openArray[uint32]) = 
  # set blending
  glEnable(GL_BLEND)
  glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD)
  glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
  checkGLError()

  state.shader.ensureProgramActive:
    state.shader.setUniform("u_transform", state.mvp)

    glBufferData(GL_ARRAY_BUFFER, cint(Vertex.sizeof * vertices.len), vertices[0].addr, GL_STATIC_DRAW)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, cint(cuint.sizeof * indices.len), indices[0].addr, GL_STATIC_DRAW)
    glDrawElements(primitivesType, indices.len.cint, GL_UNSIGNED_INT, nil)
    checkGLError()
  
  glDisable(GL_BLEND)
