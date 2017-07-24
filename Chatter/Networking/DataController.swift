/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation
import RealmSwift

class DataController {
    
    private let api: ChatterAPI
    
    init(api: ChatterAPI) {
        self.api = api
    }
    
    private var timer: Timer?
    
    // MARK: - fetch new messages
    
    func startFetchingMessages() {
        timer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(fetch), userInfo: nil, repeats: true)
        timer!.fire()
    }
    
    func stopFetchingMessages() {
        timer?.invalidate()
    }
    
    @objc fileprivate func fetch() {
        api.getMessages { (jsonObjects) in
            let newMessages = jsonObjects.map { object in
                return Message(value: object)
            }
            
            do {
                let realm = try Realm()
                let me = User.defaultUser(in: realm)
                
                do {
                    try realm.write {
                        for message in newMessages {
                            me.messages.insert(message, at: 0)
                        }
                    }
                } catch {
                    print("\(error)")
                }
            } catch {
                print("\(error)")
            }
        }
    }
    
    // MARK: - post new message
    
    func postMessage(_ message: String) {

        do {
            let realm = try Realm()
            let user = User.defaultUser(in: realm)
            let new = Message(user: user, message: message)
            do {
                try realm.write {
                    user.outgoing.append(new)
                }
                
                let newId = new.id
                api.postMessage(new, completion: { [weak self] _ in
                    self?.didSentMessage(id: newId)
                })
            } catch {
                print("\(error)")
            }
        } catch {
            print("\(error)")
        }
    }
    
    private func didSentMessage(id: String) {
        guard let realm = try? Realm() else { return }
        
        let user = User.defaultUser(in: realm)
        
        if let sentMessage = realm.object(ofType: Message.self, forPrimaryKey: id),
            let index = user.outgoing.index(of: sentMessage) {
            do {
                try realm.write {
                    user.outgoing.remove(objectAtIndex: index)
                    user.messages.insert(sentMessage, at: 0)
                    user.sent += 1
                }
            } catch {
                print("\(error)")
            }
        }
    }

}

