proc decodeByte(c: char): uint =
  if c >= '\\': (c.ord - 36).uint else: (c.ord - 35).uint

proc decodeBase85*(src: string): seq[byte] =
  var s = 0
  var d = 0
  let decodedSize = ((src.len + 4) div 5) * 4
  var dst = newSeq[byte](decodedSize)
  while s < src.len - 5:
    let tmp = decodeByte(src[s]) + 85 * (decodeByte(src[s+1]) + 85 * (decodeByte(src[s+2]) + 85 * (decodeByte(src[s+3]) + 85 * decodeByte(src[s+4]))))
    dst[d  ] = ((tmp shr 0) and 0xFF).byte
    dst[d+1] = ((tmp shr 8) and 0xFF).byte
    dst[d+2] = ((tmp shr 16) and 0xFF).byte
    dst[d+3] = ((tmp shr 24) and 0xFF).byte
    s += 5
    d += 4
  dst

when isMainModule:
  import std/strformat
  
  let data = decodeBase85("=pxq9_8v7&0C/2'K(HH=4hFJ(4hFJ(15###i><u9t%###1EHr9809Gf)9+##=<Pt8WcGP(9U&%;>GnZcY&px%t?kj;`=T'=M`qGil1vV$k.bs-Q%EI-r^@v,As:p/Ta8OPlUaW-(@Ah3qRoe`8V$t+mnvCn_,qc5$.O]Jp#47INZ8FiBR7cdOA(YdjOYo6O)*5.?'Xa)ZP95TwHLc'8;hJ6>N%3vTj.In4BFK:oD$>b=A+,10OtlHWn@wjH'^&ar$ST(FXI:Mb];J.4S)M%EV?Z4ncJsXml_M]*_nu87Ha0e&j5CR'hpJ<Jf<bFRe(hBXY;,5^RQ.-Ya'o.SrgW7isjdn;h)%'Hx+@Jq$^B$CU)wQ$0tYN5Cr_(KYveN+hojDx0'a5exZu5OT:Fep@YAmCrqF'pj_RO#x8I7M*wBd1Ju9$IX@5>5AiCY2>P2W<aB;d9<Hicob'g[$.84)>nbP0bO.h++$05/QkZJOav+IdOmRG<`&X7aBO1SPT2)]pB's_$%(dgInSa^`w9Q@)r>m0#,e0&$7:%2#/6?sC0Q/VZOG0A7Gm2%*h$###Ub90<d$bsAP$###")
  echo fmt"dataSize: {data.len}"
  echo data
  let f = open("foo.png", fmWrite)
  discard f.writeBytes(data, 0, data.len)
  f.close