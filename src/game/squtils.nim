import std/macros
import sqnim

proc regGblFun*(v: HSQUIRRELVM, f: SQFUNCTION, fname: cstring) =
  sq_pushroottable(v)
  sq_pushstring(v,fname,-1)
  sq_newclosure(v,f,0) # create a new function
  discard sq_newslot(v,-3,SQFalse)
  sq_pop(v,1) # pops the root table
  
macro sqBind*(vm, body): untyped =
  result = newStmtList()
  for bodyStmt in body:
    if bodyStmt.kind == nnkConstSection:
      # declare a constant section
      let constSection = bodyStmt
      for constDef in constSection:
        # declare a constant
        let constName = constDef[0]
        let constValue = constDef[2]
        result.add(newCall(ident("sq_pushconsttable"), vm))
        result.add(newCall(ident("sq_pushstring"), vm, newStrLitNode(constName.repr), newLit(-1)))
        result.add(newCall(ident("push"), vm, constValue))
        result.add(newNimNode(nnkDiscardStmt).add(newCall(ident("sq_newslot"), vm, newLit(-3), newLit(SQTrue))))
        result.add(newCall(ident("sq_pop"), vm, newLit(1)))
    else:
      # declare a procedure
      let procDef = bodyStmt
      let name = procDef[0]
      var stmts = newStmtList()
      procDef.expectMinLen(4)
      var params: seq[NimNode]
      for iParam in 1..procDef[3].len-1:
        # tranform each param in squirrel param
        let paramNode = procDef[3][iParam]
        let identNode = paramNode[0]
        let typeNode = paramNode[1]
        params.add(identNode)

        var stmt: NimNode
        case typeNode.repr:
        of "SQInteger":
          stmt = newCall(ident("sq_getinteger"), ident("v"), newLit(iParam+1), identNode)
        of "SQFloat":
          stmt = newCall(ident("sq_getfloat"), ident("v"), newLit(iParam+1), identNode)
        of "SQString":
          stmt = newCall(ident("sq_getstring"), ident("v"), newLit(iParam+1), identNode)
        of "HSQOBJECT":
          stmt = newCall(ident("sq_getstackobj"), ident("v"), newLit(iParam+1), identNode)
        else:
          assert false, "unexpected param type: " & typeNode.repr
        stmts.add(newNimNode(nnkVarSection).add(newIdentDefs(identNode, typeNode)))
        stmts.add(newNimNode(nnkDiscardStmt).add(stmt))
      # result
      let resultType = procDef[3][0]
      var stmt: NimNode
      case resultType.repr:
        of "SQInteger":
          stmt = newCall(ident("sq_pushinteger"), ident("v"), newCall(name, params))
        of "SQFloat":
          stmt = newCall(ident("sq_pushfloat"), ident("v"), newCall(name, params))
        of "SQString":
          stmt = newCall(ident("sq_pushstring"), ident("v"), newCall(name, params), newLit(-1))
        of "HSQOBJECT":
          stmt = newCall(ident("sq_pushobject"), ident("v"), newCall(name, params))
        of "":
          stmt = newEmptyNode()
        else:
          assert false, "unexpected result type: " & resultType.repr
      stmts.add(stmt)
      # returns 1 to indicate that this function returns a value
      stmts.add(newLit(1))
      
      # create procedures
      let sqbdName = ident("sqbd_" & name.repr)
      # register function
      let regStmt = newCall(ident("regGblFun"), vm, sqbdName, newLit(name.repr))
      # add procedure definition
      result.add(procDef)
      # add squirrel procedure definition
      result.add(newProc(sqbdName, 
        [ident("SQInteger"), newIdentDefs(ident("v"), ident("HSQUIRRELVM"))],
        stmts, pragmas = newNimNode(nnkPragma).add(ident("cdecl"))))
      result.add(regStmt)