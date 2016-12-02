import XCTest

public class Tests: XCTestCase {
  
  func testTokenizer() {
    XCTAssert(tokenize("(a b c)") == ["(", "a", "b", "c", ")"])
    XCTAssert(tokenize("a") == ["a"])
    XCTAssert(tokenize("'a") == ["'", "a"])
    XCTAssert(tokenize("(a (b) c)") == ["(", "a", "(", "b", ")", "c", ")"])
    XCTAssert(tokenize(" (a  b  c ) ") == ["(", "a", "b", "c", ")"])
    XCTAssert(tokenize(" ``(a)") == ["`", "`", "(", "a", ")"])
  }
  
  func testParser() {
    XCTAssertEqual(p(""), "()")
    XCTAssertEqual(p("()"), "()")
    XCTAssertEqual(p("a"), "a")
    XCTAssertEqual(p("(a)"), "(a)")
    XCTAssertEqual(p("(())"), "(())")
    XCTAssertEqual(p("((a) (b c))"), "((a) (b c))")
    
    // quote
    XCTAssertEqual(p("`"), "(quote ())")
    XCTAssertEqual(p("`a"), "(quote a)")
    XCTAssertEqual(p("`(a (b) c)"), "(quote (a (b) c))")
    XCTAssertEqual(p("``(a (b) c)"), "(quote (quote (a (b) c)))")
    XCTAssertEqual(p("`()"), "(quote ())")
    XCTAssertEqual(p("(a b `())"), "(a b (quote ()))")
  }
  
  func testQuote() {
    XCTAssertEqual(e("(quote ())"), "()")
    XCTAssertEqual(e("(quote a)"), "a")
    XCTAssertEqual(e("`a"), "a")
    XCTAssertEqual(e("``a"), "(quote a)")
    XCTAssertEqual(e("(quote (a b c))"), "(a b c)")
  }
  
  func testAtom() {
    XCTAssertEqual(e("(atom ())"), "t")
    XCTAssertEqual(e("(atom `a)"), "t")
    XCTAssertEqual(e("(atom `())"), "t")
    XCTAssertEqual(e("(atom `(a b c))"), "()")
    XCTAssertEqual(e("(atom `(atom `a))"), "()")
  }

  func testEq() {
    XCTAssertEqual(e("(eq `a `a)"), "t")
    XCTAssertEqual(e("(eq `() `())"), "t")
    XCTAssertEqual(e("(eq `a `b)"), "()")
    XCTAssertEqual(e("(eq `a ())"), "()")
    XCTAssertEqual(e("(eq `(a b c) `(a b c))"), "()")
  }

  func testCar() {
    XCTAssertEqual(e("(car `(a b c))"), "a")
    XCTAssertEqual(e("(car `((a) b c))"), "(a)")
    XCTAssertEqual(e("(car `())"), "()")
    XCTAssertEqual(e("(car (car `((a) b c)))"), "a")
  }

  func testCdr() {
    XCTAssertEqual(e("(cdr `((a) b c))"), "(b c)")
    XCTAssertEqual(e("(cdr `(a b c))"), "(b c)")
    XCTAssertEqual(e("(cdr `())"), "()")
  }

  func testCons() {
    XCTAssertEqual(e("(cons `a `(b c))"), "(a b c)")
    XCTAssertEqual(e("(cons `a `())"), "(a)")
    XCTAssertEqual(e("(cons `(a) `())"), "((a))")
    XCTAssertEqual(e("(cons `() `())"), "(())")
    XCTAssertEqual(e("(cons `() `(a))"), "(() a)")
    XCTAssertEqual(e("(cons `() `(a b c))"), "(() a b c)")
    XCTAssertEqual(e("(cons `(a b c) `(a b c))"), "((a b c) a b c)")
  }

  func testCond() {
    XCTAssertEqual(e("(cond ((eq `a `b) `first) ((atom `t) `second))"), "second")
    XCTAssertEqual(e("(cond ((eq `a `b) `first) ((eq `a `b) `second))"), "()")
    XCTAssertEqual(e("(cond ((eq `a `a) `first) ((eq `a `b) `second))"), "first")
    XCTAssertEqual(e("(cond (`() no) (`() `no) (`t `yes))"), "yes")
    XCTAssertEqual(e("(cond (`a `no) (`b `no) (`t `yes))"), "yes")
  }
  
  func testDo() {
    let code = "(do (defun null (x) (eq x `())) (null `(a)))"

    XCTAssertEqual(e(code), "()")
  }
    
  func testLambda() {
    XCTAssertEqual(e("((lambda (x) (cons x `(b c))) `a)"), "(a b c)")
    XCTAssertEqual(e("((lambda (x) (atom x)) `(a b c))"), "()")
    XCTAssertEqual(e("((lambda (x) (car x)) `(a b c))"), "a")
    XCTAssertEqual(e("((lambda (x) (cdr x)) `(a b c))"), "(b c)")
    XCTAssertEqual(e("((lambda (x) (quote x)) `(a b c))"), "x")
    XCTAssertEqual(e("((lambda (x) (eq x `a)) `a)"), "t")
    XCTAssertEqual(e("((lambda (x) (cond ((eq x `b) `first) ((atom x) `second))) `a)"), "second")
    XCTAssertEqual(e("((lambda (x) (eq x `a)) (car `(a)))"), "t")
  }
  
  func testLabel() {
    let simpleRecursion = "((label firstatom (lambda (x)" +
                                "(cond ((atom x) x)" +
                                        "(`t (firstatom (car x)))))) `((a b) (c d)))"
    XCTAssertEqual(e(simpleRecursion), "a")
    
    
    let heavyRecursion = "((label subst (lambda (x y z)" +
                            "(cond ((atom z) (cond ((eq z y) x) (`t z)))" +
                            "(`t (cons (subst x y (car z)) (subst x y (cdr z)))))))" +
                          "`m `b `(a b (a b) c d))"
        
    XCTAssertEqual(e(heavyRecursion), "(a m (a m) c d)")
  }
  
  func testLispInLisp() {
    // basic
    XCTAssertEqual(elil("((lambda (x y) (eq x y)) `a `a)"), "t")
    XCTAssertEqual(elil("((lambda (x y) (eq x y)) `a `b)"), "()")
    XCTAssertEqual(elil("((lambda (x) (eq x `a)) (car `(a)))"), "t")
    XCTAssertEqual(elil("`b"), "b")
    XCTAssertEqual(elil("`a"), "a")
    XCTAssertEqual(elil("(car `(o))"), "o")
    XCTAssertEqual(elil("(quote z)"), "z")
    
    // advanced
    let simpleRecursion = "((label separate (lambda (lst)" +
      "(cond" +
      "((eq (cdr lst) `()) lst)" +
      "(`t (cons (car lst) (cons `| (separate (cdr lst))))))))" +
    "`(a b (c d)))"
    XCTAssertEqual(elil(simpleRecursion), "(a | b | (c d))")
    
    let heavyRecursion = "((label subst (lambda (x y z)" +
      "(cond ((atom z) (cond ((eq z y) x) (`t z)))" +
      "(`t (cons (subst x y (car z)) (subst x y (cdr z)))))))" +
    "`m `b `(a b (a b) c d b b (((b c b)))))"
    XCTAssertEqual(elil(heavyRecursion), "(a m (a m) c d m m (((m c m))))")
  }
}

func p(_ string: String) -> String {
  return String(parse(tokenize(string)))
}

func e(_ string: String) -> String {
  return String(eval(parse(tokenize(string)), env: []).exp)
}

// eval lisp in lisp
public func elil(_ userCode: String) -> String {
  let code = "(do \(lispDefinitionCode()) (eval `\(userCode) `()))"
  return String(eval(parse(tokenize(code)), env: []).exp)
}


extension String {
  init(_ exp: Exp) {
    guard exp is Atom || exp is List else {
      fatalError("Invalid expression \(exp).")
    }
    
    if let list = exp as? List {
      self = list.description.replacingOccurrences(of: "\"", with: "")
    } else {
      self = exp as! String
    }
    
    self = self.replacingOccurrences(of: "[", with: "(")
               .replacingOccurrences(of: "]", with: ")")
               .replacingOccurrences(of: ",", with: "")
  }
}

import Foundation

func lispDefinitionCode() -> String {
  return contentsOfFile(name: "Lisp", type: "lisp").replacingOccurrences(of: "\n", with: "")
}

func contentsOfFile(name: String, type: String) -> String {
  guard let path = Bundle.main.path(forResource: name, ofType: type) else {
    return ""
  }
  
  do {
    let content = try String(contentsOfFile:path, encoding: String.Encoding.utf8)
    return content
  } catch _ as NSError {
    return ""
  }
}
