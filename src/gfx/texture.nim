import std/strformat
import glm
import image
import ../sys/opengl

type Texture* = ref object of RootObj
  id*: GLuint
  width*, height*: int

proc size*(self: Texture): Vec2i = 
  vec2(self.width.int32, self.height.int32)

proc getFormat(channels: int): GLint =
  case channels:
  of 3: result = GL_RGB.GLint
  of 4: result = GL_RGBA.GLint
  else: raiseAssert(fmt"Can't get format for {channels} channels")

proc newTexture*(image: Image): Texture =
  new(result)
  result.width = image.width
  result.height = image.height
  glGenTextures(1, addr result.id)
  glBindTexture(GL_TEXTURE_2D, result.id)
  # set the texture wrapping/filtering options (on the currently bound texture object)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
  glTexImage2D(GL_TEXTURE_2D, 0.GLint, getFormat(image.channels), image.width.GLsizei, image.height.GLsizei, 0.GLint, GL_RGBA, GL_UNSIGNED_BYTE, unsafeAddr image.data[0])
