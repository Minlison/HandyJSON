/*
 * Copyright 1999-2101 Alibaba Group.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
//  Created by zhouzhuo on 07/01/2017.
//

// MARK: MetadataType
protocol MetadataType : PointerType {
    static var kind: Metadata.Kind? { get }
}

extension MetadataType {

    var kind: Metadata.Kind {
        return Metadata.Kind(flag: UnsafePointer<Int>(pointer).pointee)
    }

    init?(type: Any.Type) {
        self.init(pointer: unsafeBitCast(type, to: UnsafePointer<Int>.self))
        if let kind = type(of: self).kind, kind != self.kind {
            return nil
        }
    }
}

// MARK: Metadata
struct Metadata : MetadataType {
    var pointer: UnsafePointer<Int>

    init(type: Any.Type) {
        self.init(pointer: unsafeBitCast(type, to: UnsafePointer<Int>.self))
    }
}

struct _Metadata {}

var is64BitPlatform: Bool {
    return MemoryLayout<Int>.size == MemoryLayout<Int64>.size
}

// MARK: Metadata + Kind
// https://github.com/apple/swift/blob/swift-3.0-branch/include/swift/ABI/MetadataKind.def
extension Metadata {
    static let kind: Kind? = nil

    enum Kind {
        case `struct`
        case `enum`
        case optional
        case opaque
        case tuple
        case function
        case existential
        case metatype
        case objCClassWrapper
        case existentialMetatype
        case foreignClass
        case heapLocalVariable
        case heapGenericLocalVariable
        case errorObject
        case `class`
        init(flag: Int) {
            switch flag {
            case 1: self = .struct
            case 2: self = .enum
            case 3: self = .optional
            case 8: self = .opaque
            case 9: self = .tuple
            case 10: self = .function
            case 12: self = .existential
            case 13: self = .metatype
            case 14: self = .objCClassWrapper
            case 15: self = .existentialMetatype
            case 16: self = .foreignClass
            case 64: self = .heapLocalVariable
            case 65: self = .heapGenericLocalVariable
            case 128: self = .errorObject
            default: self = .class
            }
        }
    }
}

// MARK: Metadata + Class
extension Metadata {
    struct Class : NominalType {

        static let kind: Kind? = .class
        var pointer: UnsafePointer<_Metadata._Class>

        var isSwiftClass: Bool {
            get {
                let lowbit = self.pointer.pointee.rodataptr & 1
                return lowbit == 1
            }
        }

        var nominalTypeDescriptorOffsetLocation: Int {
            return is64BitPlatform ? 8 : 11
        }

        var superclass: Class? {
            guard let superclass = pointer.pointee.superclass else {
                return nil
            }

            // If the superclass doesn't conform to handyjson/handyjsonenum protocol,
            // we should ignore the properties inside
            if !(superclass is HandyJSON.Type) && !(superclass is HandyJSONEnum.Type) {
                return nil
            }
            return Metadata.Class(type: superclass)
        }

        func properties() -> [Property.Description]? {
            // ignore class in objc-runtime
            if !isSwiftClass {
                return nil
            }

            var result: [Property.Description] = []

            // ignore dynamically created class such as which is obtained from `objc_allocateClassPair`
            if let _ = self.nominalTypeDescriptor,
                let properties = fetchProperties(nominalType: self) {
                result = properties
            }

            if let superclass = superclass,
                String(describing: unsafeBitCast(superclass.pointer, to: Any.Type.self)) != "SwiftObject",  // ignore the root swift object
                let superclassProperties = superclass.properties() {

                return superclassProperties + result
            }
            return result
        }
    }
}

extension _Metadata {
    struct _Class {
        var kind: Int
        var superclass: Any.Type?
        var reserveword1: Int
        var reserveword2: Int
        var rodataptr: UInt
    }
}

// MARK: Metadata + Struct
extension Metadata {
    struct Struct : NominalType {
        static let kind: Kind? = .struct
        var pointer: UnsafePointer<_Metadata._Struct>
        var nominalTypeDescriptorOffsetLocation: Int {
            return 1
        }
    }
}

extension _Metadata {
    struct _Struct {
        var kind: Int
        var nominalTypeDescriptorOffset: Int
        var parent: Metadata?
    }
}

// MARK: Metadata + ObjcClassWrapper
extension Metadata {
    struct ObjcClassWrapper: NominalType {
        static let kind: Kind? = .objCClassWrapper
        var pointer: UnsafePointer<_Metadata._ObjcClassWrapper>
        var nominalTypeDescriptorOffsetLocation: Int {
            return is64BitPlatform ? 8 : 11
        }

        var targetType: Any.Type? {
            get {
                return pointer.pointee.targetType
            }
        }
    }
}

extension _Metadata {
    struct _ObjcClassWrapper {
        var kind: Int
        var targetType: Any.Type?
    }
}
