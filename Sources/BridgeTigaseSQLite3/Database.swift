//
// Database.swift
//
// TigaseSQLite3.swift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. Look for COPYING file in the top folder.
// If not, see http://www.gnu.org/licenses/.
//

import Foundation
import SQLCipher

public typealias SQLConnection = OpaquePointer;

open class Database: DatabaseWriter {
    public let connection: SQLConnection;
    
    lazy var statementsCache = StatementCache(database: self);
    
    public var errorMessage: String? {
        if let tmp = sqlite3_errmsg(connection) {
            return String(cString: tmp);
        }
        return nil;
    }
    
    public var lastInsertedRowId: Int? {
        return Int(sqlite3_last_insert_rowid(connection));
    }
    
    public var changes: Int {
        return Int(sqlite3_changes(connection));
    }
    
    public init (path: String, flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX) throws {
        var handle: OpaquePointer? = nil;
        let code = sqlite3_open_v2(path, &handle, flags, nil);
        guard code == SQLITE_OK, let openedHandle = handle else {
            sqlite3_close_v2(handle);
            throw DBError(resultCode: code) ?? DBError.internalError;
        }
        self.connection = openedHandle;
    }
    
    deinit {
        statementsCache.invalidate();
        sqlite3_close_v2(connection);
    }
    
    public func freeMemory() {
        statementsCache.invalidate();
    }
    
}

extension Database {
    
    public func executeQueries(_ queries: String) throws {
        let code = sqlite3_exec(self.connection, queries, nil, nil, nil);
        print("executing new code, result: \(code)");
        guard let error = DBError(database: self, resultCode: code) else {
            return;
        }
        
        throw error;
    }
    
}

extension Database {
    
    public func withTransaction(_ block: (DatabaseWriter) throws -> Void) throws {
        try execute("BEGIN TRANSACTION;");
        do {
            try block(self);
            try execute("COMMIT TRANSACTION;");
        } catch {
            try execute("ROLLBACK TRANSACTION;");
            throw error;
        }
    }
    
}
