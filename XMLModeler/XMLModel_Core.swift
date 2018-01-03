//
//  XMLModel.swift
//  XMLModel
//
//  Created by GeekXiaowei on 2017/12/12.

import UIKit

/// Can the element out and into the stack
//fileprivate protocol Stackable {
//
//    associatedtype Element
//
//    mutating func push(_ element:Element)
//
//    mutating func pop() -> Element?
//
//    var top: Element? { get }
//}

/// A stack for parse the xml elemnt
fileprivate struct Stack<Element> {
    
    private var items: [Element] = []
    
    /// Push new element into the stack
    fileprivate mutating func push(_ element: Element) {
        items.append(element)
    }
    
    @discardableResult
    /// Pop the last element out the stack and return the last element if current stack have one
    fileprivate mutating func pop() -> Element? {
        if items.isEmpty {
            return nil
        }else{
            return items.removeLast()
        }
    }
    
    /// The top element of the stack if the cyrrent stack have one
    fileprivate var top: Element?{ return items.last }
    
    /// Remove all element from stack and with out keeping capacity
    fileprivate mutating func removeAll(){
        items.removeAll(keepingCapacity: false)
    }
    
    /// The count of stack items
    fileprivate var count: Int{
        return items.count
    }
}


/// The possible errors in the process of parsing xml
public enum XMLModelError: Error{
    /// placeholder error
    case null
    case invalidXMLSting
    case fileNameError(String)
    case invalidSubscriptKey(String)
    case invalidSubscriptIndex(String)
}

extension XMLModelError: LocalizedError{
    public var errorDescription: String?{
        switch self {
        case .null:
            return "The XMLModel is null"
        case .invalidXMLSting:
            return "The xml string can't be convert to data using UTF8"
        case .fileNameError(let name):
            return "Can't find the name \"\(name)\" of the file in main bundle"
        case .invalidSubscriptKey(let description):
            return description
        case .invalidSubscriptIndex(let description):
            return description
        }
    }
}

/// `XMLModel` represent the xml data,
/// The xml data possible an single XMLElement include some children elements,
/// or a list of XMLElement at the same level.
/// `XMLModel` also responsible for parsing XML data, xml string and xml file
public class XMLModel: NSObject {

    private enum RawType {
        case list,single,error
    }

    private var rawType: RawType = .error
    private var rawlist:[XMLElement] = []
    private var rawSingle:XMLElement = XMLElement(name: "")
    private var error: XMLModelError = .null

    private var rootValue: Any{
        get{
            switch rawType {
            case .list:
                return rawlist
            case .single:
                return rawSingle
            case .error:
                return error
            }
        }
        set{
            switch newValue {
            case let single as XMLElement:
                rawSingle = single
                rawType = .single
            case let list as [XMLElement]:
                rawlist = list
                rawType = .list
            case let error as XMLModelError:
                rawType = .error
                self.error = error
            default:
                rawType = .error
                error = XMLModelError.null
            }
        }
    }
    
    private init(rootValue: Any) {
        self.options = []
        super.init()
        self.rootValue = rootValue
    }
    
    private var parentElementStack: Stack<XMLElement>?
    
    private var parseError: Error?
    
    // MARK: - Converte to json
    private var arrayStack: [[String: Any]] = []
    private var selfText: String = ""
    private var root: [String: Any] = [:]
    private var currentLevel: Int = 0
    
    private let options: ParseOptions
    
    /**
     The core init method,Passing data for parse and config options,can throw errors
     
     - parameter data: the xml data for parse
     
     - parameter options: the xml parsing options
     
     - returns : an XMLModel object or throw a error
     */
    public init(data: Data, options: ParseOptions = []) throws {
        self.options = options
        super.init()
        parentElementStack = Stack<XMLElement>()
        
        let root = XMLElement(name: root_name)
        
        parentElementStack?.push(root)
        
        let parser = XMLParser(data: data)
        
        if options.contains(ParseOptions.shouldProcessNamespaces) {
            parser.shouldProcessNamespaces = true
        }
        
        parser.delegate = self
        
        parser.parse()
        
        if let error = self.parseError {
            throw error
        }else{
            self.rootValue = root
        }
    }
}

extension XMLModel {
    
    public override var description: String{
        switch rawType {
        case .single:
            return self.rawSingle.description
        case .list:
            var string = [String]()
            rawlist.forEach{ string.append($0.description) }
            return string.joined(separator: "\n")
        case .error:
            return error.errorDescription ?? "The error no description"
        }
    }
}

let root_name = "xml_model_custom_root"

extension XMLModel: XMLParserDelegate{
    
    private var toJson: Bool{
        return options.contains(.shouldConvertToJson)
    }
    
    // MARK: - xml to json
    public func parserDidStartDocument(_ parser: XMLParser) {
        
        guard toJson else { return }
        currentLevel = 0
        
        root = [:]
        
        arrayStack = [root]
        
        selfText = ""
    }
    
    // MARK: - xml to json
    public func parserDidEndDocument(_ parser: XMLParser) {
        guard toJson else { return }
        arrayStack.removeLast()
        root = arrayStack.first!
    }
    
    private var closeTop: [String: Any]{
        get{
            return arrayStack[currentLevel - 1]
        }
        set{
            arrayStack[currentLevel - 1] = newValue
        }
    }
    
    /// Do not sent message to the menthod
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        let currentNode = parentElementStack!.top!
        
        let cutrrentIndex = parentElementStack!.count
        
        let childNode = currentNode.addChildElement(name:elementName, index:cutrrentIndex, attributes: attributeDict)
        
        parentElementStack?.push(childNode)
        
        // MARK: - xml to json
        guard toJson else { return }
        currentLevel += 1
        
        if arrayStack.count == currentLevel {
            let empty = [String: Any]()
            
            arrayStack.append(empty)
            
            if (selfText as NSString).length > 0{
                var temp = closeTop
                temp["textkey"] = selfText
                closeTop = temp
                selfText = ""
            }
        }
        
    }
    
    /// Do not sent message to the menthod
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        
        if let first = string.first,first != "\n" {
            parentElementStack?.top?.text += string
        }
        
        // MARK: - xml to json
        guard toJson else { return }
        let characterSet = CharacterSet.whitespacesAndNewlines
        let text = string.trimmingCharacters(in: characterSet)
        selfText.append(text)
    }
    
    private var arraylast: [String: Any] {
        get{
            return arrayStack[currentLevel]
        }
        set{
            arrayStack[currentLevel] = newValue
        }
    }
    
    /// Do not sent message to the menthod
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
    
        parentElementStack?.pop()
        
        // MARK: - xml to json
        guard toJson else { return }
        if arraylast.count == 0 {
            
            if let value = closeTop[elementName]{

                if value is [String] {
                    var temp = (value as! [String])
                    temp.append(selfText)
                    closeTop[elementName] = temp
                }else{
                    
                    let array = [closeTop[elementName],selfText]
                    var temp = closeTop
                    temp[elementName] = array
                    closeTop = temp

                }
            }else{
                var temp = closeTop
                temp[elementName] = selfText
                closeTop = temp
            }
            
            selfText = ""
            
        }else{
            
            if (selfText as NSString).length > 0 {
                var temp = arraylast
                temp["textkey"] = selfText
                arraylast = temp
                selfText = ""
            }
            
            if let value = closeTop[elementName]{
                
                if value is [[String: Any]]{
                    var temp = closeTop[elementName] as! [[String: Any]]
                    temp.append(arraylast)
                    closeTop[elementName] = temp
                }else if value is [String: Any] {
                    let array = [value,arraylast]
                    var temp = closeTop
                    temp[elementName] = array
                    closeTop = temp
                }
                
            }else{
                var temp = closeTop
                temp[elementName] = arraylast
                closeTop = temp
            }
            
            arrayStack.remove(at: currentLevel)
        }
        currentLevel -= 1
    }
    
    /// Do not sent message to the menthod
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
    
}

extension XMLModel{
    
    
    
}

extension XMLModel {

    /// Some xml parse options
    public struct ParseOptions: OptionSet{
        public let rawValue: UInt
        public init(rawValue: UInt){ self.rawValue = rawValue }
        /// This option can process the xml name spaces
        public static let shouldProcessNamespaces = ParseOptions(rawValue: 0)
        /// Convert the xml to json,you can read the json
        public static let shouldConvertToJson = ParseOptions(rawValue: 1)
    }

    /**
     The convenience init method,for parse xml string with options,can throw errors
     
     - parameter xmlString: the xml string for parse,the string will be convert to data using UTF8
     
     - parameter options: the xml parsing options
     
     - returns : an XMLModel object or throw a error
     */
    public convenience init(xmlString: String, options: ParseOptions = []) throws {
        guard let data = xmlString.data(using: .utf8) else {
            throw XMLModelError.invalidXMLSting
        }
        try self.init(data: data, options: options)
    }
    
    /**
     The convenience init method,Passing xml file name for parse and config options
     
     - parameter xmlfile: the xml file for parse,the string will be convert to data using UTF8
 
     - parameter options: the xml parsing options
     
     - returns : an XMLModel object or throw a error
     */
    public convenience init(xmlfile name: String, options: ParseOptions = []) throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: "xml") else {
            throw XMLModelError.fileNameError(name)
        }
        let data = try Data(contentsOf: url)
        try self.init(data: data, options: options)
    }
    
    /// Just the wrapper of `init(data: Data, options: ParseOptions = []) throws`,the init method throw error cause crash
    public class func parse(data: Data, options: ParseOptions = []) -> XMLModel{
        do {
            return try XMLModel(data: data, options: options)
        } catch {
            preconditionFailure("XMLModel parse data error \(error)")
        }
    }
    
    /// Just the wrapper of `convenience init(xmlString: String, options: ParseOptions = []) throws`,the init method throw error cause crash
    public class func parse(xmlString: String, options: ParseOptions = []) -> XMLModel{
        do {
            return try XMLModel(xmlString: xmlString, options: options)
        } catch  {
            preconditionFailure("XMLModel parse xmlString error \(error)")
        }
    }
    
    /// Just the wrapper of `convenience init(xmlfile name: String, options: ParseOptions = []) throws`,the init method throw error cause crash
    public class func parse(xmlfile name: String, options: ParseOptions = []) -> XMLModel{
        do {
            return try XMLModel(xmlfile: name, options: options)
        } catch {
            preconditionFailure("XMLModel parse xmlfile error \(error)")
        }
    }
}


extension XMLModel{
    
//    private func isSubscriptKey(_ key: String) -> Bool{
//        switch rawType {
//        case .single:
//            return rawSingle.childElement.contains{ $0.name == key }
//        default:
//            return false
//        }
//    }
//
//    private func canSubscriptIndex(_ index: Int) -> Bool{
//        switch rawType{
//        case .list:
//            return rawlist.count > index
//        default:
//            return false
//        }
//    }
//
//    public subscript(_ key: String) -> XMLModel? {
//        guard isSubscriptKey(key) else { return nil }
//        let matchs = rawSingle.childElement.filter{ $0.name == key }
//        let wrappedMatch = matchs.map { $0.new() }
//        wrappedMatch.forEach{ $0.thorough{ $0.index -= 1 } }
//        if wrappedMatch.count == 1 {
//            return XMLModel(rootValue: wrappedMatch[0])
//        }else{
//            return XMLModel(rootValue: wrappedMatch)
//        }
//    }
//
//    public subscript(_ index: Int) -> XMLModel? {
//        guard canSubscriptIndex(index) else { return nil }
//        return XMLModel(rootValue: rawlist[index])
//    }

    public subscript(key: String) -> XMLModel {
        
        func makeError(description: String) -> XMLModel {
            let error = XMLModelError.invalidSubscriptKey(description)
            return XMLModel(rootValue: error)
        }
        
        switch rawType{
        case .single:
            let match = rawSingle.childElement.filter{ $0.name == key }
            let copyMatch = match.map{ $0.new() }
            copyMatch.forEach{ $0.thorough{ $0.index -= 1 } }
            if copyMatch.count == 1 {
                return XMLModel(rootValue: copyMatch[0])
            }else if copyMatch.count > 1 {
                return XMLModel(rootValue: copyMatch)
            }else{
                let description = "The key: \"\(key)\" didn't match the element name,check out it"
                return makeError(description: description)
            }
        case .list:
            let description = "Current xml is list,unsupport key:\(key)"
            return makeError(description: description)
        default:
            let description = "There is an error\(error)"
            return makeError(description: description)
        }
    }
    
    
    public subscript(index: Int) -> XMLModel{
        
        func makeError(description: String) -> XMLModel {
            let error = XMLModelError.invalidSubscriptIndex(description)
            return XMLModel(rootValue: error)
        }
        
        switch rawType{
        case .list:
            if rawlist.count > index{
                return XMLModel(rootValue: rawlist[index])
            }else{
                let description = "The index:\(index) out of index"
                return makeError(description: description)
            }
        case .single:
            let description = "Current xml is not a list,unsupport index:\(index)"
            return makeError(description: description)
        case .error:
            let description = "Current XMLModel is an error\(error)"
            return makeError(description: description)
        }
    }
    
}

/// Represent the XML element
public class XMLElement {
    
    /// Define the XML element attribute
    public struct Attribute{
        
        /// The name of the attribute
        public let name: String
        
        /// The text of the attribute
        public let text: String
    }
    
    /// The name of the element
    public let name: String
    
    /// Indicates that the current element in the element hierarchy
    public var index: Int
    
    /// The text of the element, if the text is not exist,the string is empty
    public var text: String = ""
    
    /// The child elements of the element, if it not exists,the array is empty
    public var childElement: [XMLElement] = []
    
    ///The attributes of the element,if it not exists,the dictionary is empty
    public var attributes: [String: Attribute] = [:]
    
    /// Create and return an element
    public init(name: String, index: Int = 0){
        self.name = name
        self.index = index
    }
    
    fileprivate func addChildElement(name: String,index: Int,attributes: [String: String]) -> XMLElement
    {
        let element = XMLElement(name: name, index: index)
        
        childElement.append(element)
        
        for (key, value) in attributes {
            element.attributes[key] = Attribute(name: key, text: value)
        }
        
        return element
    }
    
    fileprivate func thorough(operation: (XMLElement) -> Void ) {
        operation(self)
        childElement.forEach{ $0.thorough(operation: operation) }
    }
}


extension XMLElement.Attribute: CustomStringConvertible{
    
    public var description: String{
        return "\(name)=\"\(text)\""
    }
}

extension XMLElement: CustomStringConvertible{
    
    public var description: String{
        
        let attributesString = attributes.reduce("", { $0 + " " + $1.1.description })
        
        var startTag = String(repeating: "    ", count: index) + "<\(name)\(attributesString)>"
        if !childElement.isEmpty { startTag += "\n"}
        
        var endTag: String
        if childElement.isEmpty {
            endTag = "</\(name)>"
        }else{
            endTag = String(repeating: "    ", count: index) + "</\(name)>"
        }
        
        if !(index == 0) { endTag += "\n" }
        
        if childElement.isEmpty {
            return startTag + text + endTag
        }else{
            let mid = childElement.reduce("") {$0 + $1.description}
            return startTag + mid + endTag
        }
    }
}


extension XMLElement {
    /// The new func alloc a new XMLElement
    public func new() -> XMLElement {
        let element = XMLElement(name: name, index: index)
        element.text = text
        element.attributes = attributes
        element.childElement = childElement.map{ $0.new() }
        return element
    }
    
}



extension XMLModel{
    
    /// The element of the current level,none optional value
    public var element: XMLElement{
        switch rawType {
        case .single:
            return rawSingle
        case .list:
            fatalError("Current XMLModel a list of XMLElements ,no element value")
        case .error:
            fatalError("XMLModel is an error")
        }
    }
    
    /// The element of the current level,optional value
    public var elementValue: XMLElement?{
        switch rawType {
        case .single:
            return rawSingle
        default:
            return nil
        }
    }
}



/// 最后一部分是转换模型
/// 下面这种方式来自 SWXMLHash
/// 针对比较小一点的数据模型还好，如果数据模型比较大，这种方式的写法非常繁琐
/// 上面提供了将xml转换成json数据选项
/// 可以将xml先准换成json再使用标准库提供的转模型方法进行转换

/// The default array of true value strings,you can change the strings to meet the requirements of the current
public var Represent_True_Strings = ["true","1","yes"]
/// The default array of false value strings,you can change the strings to meet the requirements of the current
public var Represent_False_Strings = ["false","0","no"]
extension String{
    /**
     Convert string to bool value case sensitive.
     
     - parameter caseSensitive: default is true
     - returns: optional bool value
     */
    func bool(_ caseSensitive: Bool = true) -> Bool? {
        if caseSensitive {
            if Represent_True_Strings.contains(self){
                return true
            }else if Represent_False_Strings.contains(self){
                return false
            }else{
                return nil
            }
        }else{
            if Represent_True_Strings.contains(lowercased()){
                return true
            }else if Represent_False_Strings.contains(lowercased()){
                return false
            }else{
                return nil
            }
        }
    }
}

//public protocol XMLModelCodable{
//
//    static func decode(xmlModel:XMLModel) -> Self
//}
//
//
//
//extension String: XMLModelCodable{
//
//    public static func decode(xmlModel: XMLModel) -> String {
//        return xmlModel.element.text
//    }
//}
//
//extension Double: XMLModelCodable{
//
//    public static func decode(xmlModel: XMLModel) -> Double {
//        if let value = Double(xmlModel.element.text) {
//            return value
//        }else{
//            fatalError("")
//        }
//    }
//}
//
//extension Int: XMLModelCodable{
//
//    public static func decode(xmlModel: XMLModel) -> Int {
//        if let value = Int(xmlModel.element.text) {
//            return value
//        }else{
//            fatalError("Current ")
//        }
//    }
//}
//
//extension Float: XMLModelCodable{
//
//    public static func decode(xmlModel: XMLModel) -> Float {
//        if let value = Float(xmlModel.element.text) {
//            return value
//        }else{
//            fatalError("")
//        }
//    }
//
//
//}
//
//extension Bool: XMLModelCodable{
//
//    public static func decode(xmlModel: XMLModel) -> Bool {
//        if let bool = xmlModel.element.text.bool() {
//            return bool
//        }else{
//            fatalError()
//        }
//    }
//
//}
//
//extension XMLModel{
//
//    func model<T: XMLModelCodable>() -> [T] {
//        if rawType == .error { fatalError() }
//        switch rawType {
//        case .list:
//            return rawlist.map{ T.decode(xmlModel: XMLModel(rootValue:$0)) }
//        default:
//            fatalError()
//        }
//    }
//
//    func model<T: XMLModelCodable>() -> T {
//        if rawType == .error { fatalError() }
//        switch rawType {
//        case .single:
//            return T.decode(xmlModel: self)
//        default:
//            fatalError()
//        }
//    }
//
//    func model<T: XMLModelCodable>() -> T? {
//        if rawType == .error { return nil }
//        switch rawType {
//        case .single:
//            return T.decode(xmlModel: self)
//        default:
//            return nil
//        }
//    }
//
//}

