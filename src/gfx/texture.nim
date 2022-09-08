import std/strformat
import glm
import image
import ../libs/opengl

type
  Texture* = ref object of RootObj
    id*: GLuint
    width*, height*: int
    fbo*: GLuint
  RenderTexture* = ref object of Texture

proc size*(self: Texture): Vec2i = 
  vec2(self.width.int32, self.height.int32)

proc getFormat(channels: int): GLint =
  case channels:
  of 3: result = GL_RGB.GLint
  of 4: result = GL_RGBA.GLint
  else: raiseAssert(fmt"Can't get format for {channels} channels")

proc newTexture*(image: Image): Texture =
  result = Texture(width: image.width, height: image.height)
  glGenTextures(1, addr result.id)
  glBindTexture(GL_TEXTURE_2D, result.id)
  # set the texture wrapping/filtering options (on the currently bound texture object)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
  glTexImage2D(GL_TEXTURE_2D, 0.GLint, getFormat(image.channels), image.width.GLsizei, image.height.GLsizei, 0.GLint, GL_RGBA, GL_UNSIGNED_BYTE, unsafeAddr image.data[0])

proc capture*(self: Texture): Image =
  var pixels = newSeq[byte](self.size.x * self.size.y * 4)
  var boundFrameBuffer: GLint
  
  glGetIntegerv(GL_FRAMEBUFFER_BINDING, addr boundFrameBuffer)
  if boundFrameBuffer.GLuint != self.fbo:
    glBindFramebuffer(GL_FRAMEBUFFER, self.fbo)
  glReadPixels(0, 0, self.size.x, self.size.y, GL_RGBA, GL_UNSIGNED_BYTE, pixels[0].addr)
  if boundFrameBuffer.GLuint != self.fbo:
    glBindFramebuffer(GL_FRAMEBUFFER, boundFrameBuffer.GLuint)

  newImage(self.size, 4, pixels)

proc capture*(self: Texture, filename: string) =
  let img = self.capture()
  img.writePNG(filename)

proc destroy*(self: Texture) =
  glDeleteTextures(1, addr self.id)

proc newRenderTexture*(size: Vec2i): RenderTexture =
  result = RenderTexture(width: size.x, height: size.y)

  # first create the framebuffer
  glGenFramebuffers(1, addr result.fbo)
  glBindFramebuffer(GL_FRAMEBUFFER, result.fbo)

  # then create an empty texture
  glGenTextures(1, addr result.id)
  glBindTexture(GL_TEXTURE_2D, result.id)
  glTexImage2D(GL_TEXTURE_2D, 0.GLint, GL_RGBA.GLint, size.x, size.y, 0, GL_RGBA, GL_UNSIGNED_BYTE, nil)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
  glBindTexture(GL_TEXTURE_2D, 0)

  # then attach it to framebuffer object
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, result.id, 0)
  assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE)
  glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc destroy*(self: RenderTexture) =
  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  glDeleteTextures(1, addr self.id)
  glDeleteFramebuffers(1, addr self.fbo)
