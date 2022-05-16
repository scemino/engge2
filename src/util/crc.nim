func createCrcTable(): array[0..255, uint32] =
  for i in 0.uint32..255.uint32:
    var rem = i
    for j in 0..7:
      if (rem and 1) > 0'u32: rem = (rem shr 1) xor uint32(0xedb88320)
      else: rem = rem shr 1
    result[i] = rem

template updateCrc32(c: char; crc: var uint32) =
  crc = (crc shr 8) xor static(createCrcTable())[uint32(crc and
      0xff) xor uint32(ord(c))]

func crc32*(input: string): uint32 =
  result = uint32(0xFFFFFFFF)
  for c in input: updateCrc32(c, result)
  result = not result

when isMainModule:
  import strutils
  doAssert crc32("The quick brown fox jumps over the lazy dog.").toHex == "519025E9"