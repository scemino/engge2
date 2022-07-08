import ../libs/opengl
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
  gEmptyTexture*: Texture

proc drawSpriteCore(textRect: Rectf, w, h: float32; color = White; transf = mat4f(1.0); flipX = false)
proc drawPrimitives*(primitivesType: GLenum, vertices: var openArray[Vertex]; transf = mat4f(1.0))
proc drawPrimitives*(primitivesType: GLenum, vertices: var openArray[Vertex], indices: var openArray[uint32]; transf = mat4f(1.0))

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
  state.texture = gEmptyTexture
  glBindTexture(GL_TEXTURE_2D, gEmptyTexture.id)

proc gfxShader*(shader: Shader) =
  state.shader = shader

proc gfxShader*(): Shader =
  state.shader

proc gfxResetShader*() =
  state.shader  = newShader(vsrc, fsrc)

proc gfxInit*() =
  emptyImage = newImage(1, 1, 4, @[0xFF'u8, 0xFF, 0xFF, 0xFF])
  gEmptyTexture = newTexture(emptyImage)

  state.shader  = newShader(vsrc, fsrc)
  state.color   = vec3(1f, 1f, 1f)
  state.mvp     = ortho(-1f, 1f, -1f, 1f, -1f, 1f)
  state.texture = gEmptyTexture

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

proc gfxDraw*(vertices: var openArray[Vertex], indices: var openArray[uint32]; transf = mat4f(1.0)) =
  drawPrimitives(GL_TRIANGLES, vertices, indices, transf)

proc gfxDraw*(vertices: var openArray[Vertex]; transf = mat4f(1.0)) =
  drawPrimitives(GL_TRIANGLES, vertices, transf)

proc gfxDrawSprite*(texture: Texture; color = White; transf = mat4f(1.0); flipX = false) =
  texture.bindTexture()
  drawSpriteCore(rect(0f, 0f, 1f, 1f), texture.width.float32, texture.height.float32, color, transf, flipX)

proc gfxDrawSprite*(w,h: float, texture: Texture; color = White; transf = mat4f(1.0); flipX = false) =
  texture.bindTexture()
  drawSpriteCore(rect(0f, 0f, 1f, 1f), w.float32, h.float32, color, transf, flipX)

proc gfxDrawSprite*(textRect: Rectf, texture: Texture; color = White; transf = mat4f(1.0); flipX = false) =
  let w = textRect.w * texture.width.float32
  let h = textRect.h * texture.height.float32
  texture.bindTexture()
  drawSpriteCore(textRect, w, h, color, transf, flipX)

proc gfxDrawSprite*(pos: Vec2f, textRect: Rectf, texture: Texture; color = White; flipX = false) =
  gfxDrawSprite(textRect, texture, color, translate(mat4f(1.0), vec3(pos, 0.0)), flipX)

proc gfxDrawLines*(vertices: var openArray[Vertex]; transf = mat4f(1.0)) =
  noTexture()
  drawPrimitives(GL_LINES, vertices, transf)

proc gfxDrawLineLoop*(vertices: var openArray[Vertex]; transf = mat4f(1.0)) =
  noTexture()
  drawPrimitives(GL_LINE_LOOP, vertices, transf)

proc drawSpriteCore(textRect: Rectf, w, h: float32; color = White; transf = mat4f(1.0); flipX = false) =
  var l = textRect.x.float32
  var r = (textRect.x + textRect.w).float32
  let t = textRect.y.float32
  let b = (textRect.y + textRect.h).float32
  if flipX:
    swap(l, r)

  var vertices = [
    newVertex(w, h, r, t, color),
    newVertex(w, 0, r, b, color),
    newVertex(0, 0, l, b, color),
    newVertex(0, h, l, t, color)
  ]
  gfxDraw(vertices, quadIndices, transf)

proc gfxDrawQuad*(pos = Vec2f(); size = Vec2f(); color = White; transf = mat4f(1.0)) =
  var w = size.x
  var h = size.y
  var vertices = [
    newVertex(pos.x+w, pos.y+h, 1, 0, color),
    newVertex(pos.x+w, pos.y,   1, 1, color),
    newVertex(pos.x,   pos.y,   0, 1, color),
    newVertex(pos.x,   pos.y+h, 0, 0, color)
  ]
  noTexture()
  gfxDraw(vertices, quadIndices, transf)

proc gfxDrawQuad*(rect = Rectf(); color = White; transf = mat4f(1.0)) =
  gfxDrawQuad(rect.bottomLeft(), rect.size(), color, transf)

proc getFinalTransform(transf: Mat4f): Mat4f =
  state.mvp * transf

proc drawPrimitives*(primitivesType: GLenum, vertices: var openArray[Vertex]; transf = mat4f(1.0)) = 
  # set blending
  glEnable(GL_BLEND)
  glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD)
  glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
  checkGLError()

  state.shader.ensureProgramActive:
    state.shader.setUniform("u_transform", getFinalTransform(transf))

    glBufferData(GL_ARRAY_BUFFER, cint(Vertex.sizeof * vertices.len), vertices[0].addr, GL_STATIC_DRAW)
    glDrawArrays(primitivesType, 0, vertices.len.GLsizei)
    checkGLError()
  
  glDisable(GL_BLEND)

proc drawPrimitives*(primitivesType: GLenum, vertices: var openArray[Vertex], indices: var openArray[uint32]; transf = mat4f(1.0)) = 
  # set blending
  glEnable(GL_BLEND)
  glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD)
  glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
  checkGLError()

  state.shader.ensureProgramActive:
    state.shader.setUniform("u_transform", getFinalTransform(transf))

    glBufferData(GL_ARRAY_BUFFER, cint(Vertex.sizeof * vertices.len), vertices[0].addr, GL_STATIC_DRAW)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, cint(cuint.sizeof * indices.len), indices[0].addr, GL_STATIC_DRAW)
    glDrawElements(primitivesType, indices.len.cint, GL_UNSIGNED_INT, nil)
    checkGLError()
  
  glDisable(GL_BLEND)
