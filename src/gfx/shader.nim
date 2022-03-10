import ../sys/opengl
import std/[logging, strutils, strformat]
import glm
import glutils

type 
  Shader* = object
    program*: GLuint
    vertex: GLuint
    fragment: GLuint

proc statusShader(shader: uint32) =
  var status: int32
  glGetShaderiv(shader, GL_COMPILE_STATUS, status.addr)
  if status != GL_TRUE.ord:
    var
      log_length: int32
      message = newString(1024)
    glGetShaderInfoLog(shader, 1024, log_length.addr, message[0].addr)
    warn(message)

proc loadShader(code: cstring, shaderType: GLEnum): GLuint =
  result = glCreateShader(shaderType)
  glShaderSource(result, 1'i32, code.unsafeAddr, nil)
  glCompileShader(result)
  statusShader(result)

proc newShader*(vertex, fragment: string): Shader =
  if vertex.len > 0:
    result.vertex = loadShader(vertex, GL_VERTEX_SHADER)
  if fragment.len > 0:
    result.fragment = loadShader(fragment, GL_FRAGMENT_SHADER)
  result.program = glCreateProgram()
  glAttachShader(result.program, result.vertex)
  glAttachShader(result.program, result.fragment)
  glLinkProgram(result.program)

  var
    log_length: int32
    message = newString(1024)
    pLinked: int32
  glGetProgramiv(result.program, GL_LINK_STATUS, pLinked.addr)
  if pLinked != GL_TRUE.ord:
    glGetProgramInfoLog(result.program, 1024, log_length.addr, message[0].addr)
    warn(message)

template ensureProgramActive*(self: Shader, statements: untyped) =
  var prev = 0.GLint
  glGetIntegerv(GL_CURRENT_PROGRAM, addr prev)
  if prev != self.program.GLint:
    glUseProgram(self.program)
  glActiveTexture(GL_TEXTURE0)
  statements
  if prev != self.program.GLint:
    glUseProgram(prev.GLuint)

proc getUniformLocation*(self: Shader, name: string): GLint =
  result = glGetUniformLocation(self.program, name.cstring)
  checkGLError(fmt"getUniformLocation({name})")

proc setUniform*(self: Shader, name: string, value: int) =
  self.ensureProgramActive():
    let loc = self.getUniformLocation(name)
    glUniform1i(loc, value.GLint)
    checkGLError(fmt"setUniform({name},{value})")

proc setUniform*(self: Shader, name: string, value: Vec2f) =
  self.ensureProgramActive():
    let loc = self.getUniformLocation(name)
    var v = value
    glUniform2fv(loc, 1, v.caddr)
    checkGLError(fmt"setUniform({name},{value})")

proc setUniform*(self: Shader, name: string, value: Vec3f) =
  self.ensureProgramActive():
    let loc = self.getUniformLocation(name)
    var v = value
    glUniform3fv(loc, 1, v.caddr)
    checkGLError(fmt"setUniform({name},{value})")

proc setUniform*(self: Shader, name: string, value: Mat4f) =
  self.ensureProgramActive():
    let loc = self.getUniformLocation(name)
    var v = value
    glUniformMatrix4fv(loc, 1, false, v.caddr)
    checkGLError(fmt"setUniform({name},{value})")
