public typealias Exp = Any
public typealias List = Array<Any>
public typealias Atom = String

public func tokenize(_ string: String) -> Array<String> {
  return string.replacingOccurrences(of: "(", with: " ( ")
    .replacingOccurrences(of: ")", with: " ) ")
    .replacingOccurrences(of: "`", with: " ` ")
    .replacingOccurrences(of: "'", with: " ' ")
    .components(separatedBy: " ")
    .filter { $0 != "" }
}

var tokens: [String] = []
public func parse(_ t: [String]) -> Exp {
  tokens = t
  
  if tokens.count == 0 {
    return []
  }
  
  var exp: Exp = ""
  
  let token = tokens.removeFirst()
  switch token {
  case "`", "'":
    exp = ["quote", parse(tokens)]
  case "(":
    var list = List()
    while tokens.first != ")" {
      list.append(parse(tokens))
    }
    exp = list
    tokens.removeFirst()
  case ")": break // wtf?
  default:
    return token
  }
  
  return exp
}

let builtIn: [Atom : (List, [List]) -> (exp: Exp, env: [List])] = [
  "quote" : { (list, env) in
    assert(list.count == 1, "'quote' takes 1 argument only")
    return (list[0], env)
  },
  
  "atom" : { (list, env) in
    assert(list.count == 1, "'atom' takes 1 argument only")
    let (result, _) = eval(list[0], env: env)

    switch result {
    case let list as List where list.count == 0:
      return ("t", env)
    case is Atom:
      return ("t", env)
    default:
      return ([], env)
    }
  },
  
  "eq" : { (list, env) in
    assert(list.count == 2, "'eq' takes 2 arguments only")
    
    let (exp1, _) = eval(list[0], env: env)
    let (exp2, _) = eval(list[1], env: env)
    
    switch (exp1, exp2) {
    case let (l1 as List, l2 as List) where l1.count == 0 && l2.count == 0:
      return ("t", env)
    case let (a1 as Atom, a2 as Atom) where a1 == a2:
      return ("t", env)
    default:
      return ([], env)
    }
  },
  
  "car" : { (list, env) in
    assert(list.count == 1, "'car' takes 1 argument only")
    
    let (exp, _) = eval(list[0], env: env)
    switch exp {
    case is Atom:
      fatalError("\(exp) is not a list.")
    case let l as List where l.count > 0:
      return (l[0], env)
    default:
      return ([], env)
    }
  },
  
  "cdr" : { (list, env) in
    assert(list.count == 1, "'cdr' takes 1 argument only")
    
    let (exp, _) = eval(list[0], env: env)
    switch exp {
    case is Atom:
      fatalError("\(exp) is not a list.")
    case let l as List:
      return (l.tail, env)
    default:
      return ([], env)
    }
  },
  
  "cons" : { (list, env) in
    assert(list.count == 2, "'cons' takes 2 arguments only")
    
    let (exp1, _) = eval(list[0], env: env)
    let (exp2, _) = eval(list[1], env: env)
    switch (exp1, exp2) {
    case (_ ,is Atom):
      fatalError("\(exp2) is not a list.")
    case (_, let l as List):
      return ([exp1] + l, env)
    default:
      return ([], env)
    }
  },
  
  "cond" : { (list, env) in
    assert(list.count > 1, "'cond' takes 1 or more arguments")
    
    for pair in list {
      switch pair {
      case let l as List where l.count == 2:
        let (exp, _) = eval(l[0], env: env)
        if case let a as Atom = exp, a == "t" {
          return eval(l[1], env: env)
        }
      default:
        fatalError("'cond' takes lists with 2 expressions only")
      }
    }
    return ([], env)
  },
  
  "defun" : { (list, env) in
    assert(list.count == 3, "'defun' takes 3 arguments only")
    
    let (name, args, body) = (list[0], list[1], list[2])
    let pair = [name, ["label", name, ["lambda", args, body]]]
    
    return ([], [pair] + env)
  },
  
  "do" : { (list, env) in
    var (exp, updatedEnv) = ("" as Exp, env)
    for item in list {
      (exp, updatedEnv) = eval(item, env: updatedEnv)
    }
    return (exp, updatedEnv)
  },

]

public func eval(_ exp: Exp, env: [List]) -> (exp: Exp, env: [List]) {
  switch exp {
  case let list as List where list.count > 1: return eval(list: list, env: env)
  case let atom as Atom: return eval(atom: atom, env: env)
  case is List: return (exp, env)
  default: fatalError("Expression must either be an Atom or a List.")
  }
}

public func eval(list: List, env: [List]) -> (exp: Exp, env: [List]) {
  if list.count == 0 {
    return (list, env)
  }
  
  switch list[0] {
  case let atom as Atom:
    if let exp = lookUp(atom: atom, inEnv: env) {
      return eval(list.count > 0 ? [exp] + list.tail: exp, env: env)
    }

    if let fn = builtIn[atom] {
      return fn(list.tail, env)
    }
    
  case let l as List where l.head is Atom:
    if (l.head as! Atom) == "label" {
      return eval(label: list, env: env)
    }
    if (l.head as! Atom) == "lambda" {
      return eval(lambda: list, env: env)
    }
  default:
    fatalError("Invalid expression: \(list)")
  }
  return ("", env)
}

func eval(lambda list: List, env: [List]) -> (exp: Exp, env: [List]) {
  // ((lambda (y) (atom `y)) z)
  guard let head = list[0] as? List else {
    fatalError("Invalid lambda format.")
  }
  switch (head[0], head[1], head[2], list.tail) {
  case let (_, sign as List, body as List, args)
    where sign.count == args.count:
    
    var pairs = [List]()
    for i in 0..<args.count {
      let (key, value) = (sign[i], eval(args[i], env: env).exp)
      pairs.append([key, value])
    }
    let exp = eval(body, env: pairs + env).exp
    return (exp, env)
  default:
    break
  }
  
  return ("", [[]])
}

func eval(label list: List, env: [List]) -> (exp: Exp, env: [List]) {
  guard let head = list[0] as? List else {
    fatalError("Invalid label format.")
  }
  
  let newEnv = [[head[1], head]] + env
  let e = [head[2]] + list.tail
  let (exp, _) = eval(e, env: newEnv)
  return (exp, env)
}


public func eval(atom: Atom, env: [List]) -> (exp: Exp, env: [List]) {
  guard let exp = lookUp(atom: atom, inEnv: env) else {
    fatalError("\(atom) is not defined!")
  }
  return (exp, env)
}

public func lookUp(atom: Atom, inEnv env: [List]) -> Exp? {
  for list in env {
    if let a = list[0] as? Atom, a == atom {
      return list[1]
    }
  }
  return nil
}

extension Array {
  var head: Element {
    return first!
  }
  var tail: [Element] {
    return count > 0 ? Array(self[1..<count]) : []
  }
}
