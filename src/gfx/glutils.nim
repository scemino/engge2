import ../sys/opengl
import std/[logging, strutils]

template checkGLError*(info = "") =
  let lineinfo = instantiationInfo(fullPaths = true)
  let err = glGetError()
  if err != GL_NO_ERROR:
    var name, desc: string
    case err:
    of GL_INVALID_ENUM:
      name = "GL_INVALID_ENUM";
      desc = "An unacceptable value is specified for an enumerated argument.";
    of GL_INVALID_VALUE:
      name = "GL_INVALID_VALUE";
      desc = "A numeric argument is out of range.";
    of GL_INVALID_OPERATION:
      name = "GL_INVALID_OPERATION";
      desc = "The specified operation is not allowed in the current state.";
    of GL_INVALID_FRAMEBUFFER_OPERATION:
      name = "GL_INVALID_FRAMEBUFFER_OPERATION";
      desc = "The command is trying to render to or read from the framebuffer while the currently bound framebuffer is not framebuffer complete.";
    of GL_OUT_OF_MEMORY:
      name = "GL_OUT_OF_MEMORY";
      desc = "There is not enough memory left to execute the command.";
    else:
      name = $cast[int](err)
      desc = "?"
    var message = join([name, " at ", lineinfo.filename, ":", $lineinfo.line, "(", info, ")"])
    warn(message)