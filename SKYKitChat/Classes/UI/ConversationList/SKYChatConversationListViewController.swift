//
//  SKYChatConversationListViewController.swift
//  SKYKitChat
//
//  Copyright 2016 Oursky Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import SVProgressHUD

@objc public protocol SKYChatConversationListViewControllerDataSource: class {
    /**
     * Return the avatar image for a conversation. Returning nil will remove the avatar image view
     * when displaying the conversation.
     **/
    @objc optional func listViewController(_ controller: SKYChatConversationListViewController,
                                           avatarImageForConversation conversation: SKYConversation,
                                           atIndexPath indexPath: IndexPath) -> UIImage?
}

@objc public protocol SKYChatConversationListViewControllerDelegate: class {
    /**
     * Notify the delegate which conversation is selected.
     **/
    @objc optional func listViewController(_ controller: SKYChatConversationListViewController,
                                           didSelectConversation conversation: SKYConversation)
}

open class SKYChatConversationListViewController: UIViewController {

    public var skygear: SKYContainer = SKYContainer.default()
    public weak var delegate: SKYChatConversationListViewControllerDelegate?
    public weak var dataSource: SKYChatConversationListViewControllerDataSource?

    @IBOutlet public var tableView: UITableView!

    var userConversations: [SKYUserConversation] = []
}

// MARK: - Initializing

extension SKYChatConversationListViewController {

    public class var nib: UINib {
        return  UINib(nibName: "SKYChatConversationListViewController",
                      bundle: Bundle(for: SKYChatConversationListViewController.self))
    }

    public class func create() -> SKYChatConversationListViewController {
        return SKYChatConversationListViewController(nibName: "SKYChatConversationListViewController",
                                                     bundle: Bundle(for: SKYChatConversationListViewController.self))
    }
}

// MARK: - Lifecycle

extension SKYChatConversationListViewController {

    open override func viewDidLoad() {
        super.viewDidLoad()

        SKYChatConversationListViewController.nib.instantiate(withOwner: self, options: nil)

        self.tableView.register(SKYChatConversationTableViewCell.nib,
                                forCellReuseIdentifier: "ConversationCell")
    }

    open override func viewWillAppear(_ animated: Bool) {
        guard self.skygear.chatExtension != nil else {
            print("Missing chat extension in Skygear container")
            self.dismiss(animated: animated)
            return
        }

        if let _ = self.navigationController {
            self.edgesForExtendedLayout = [.left, .right, .bottom]
        }

        self.performQuery()
    }

    func dismiss(animated: Bool) {
        if let nc = self.navigationController, let topVC = nc.topViewController {
            guard self == topVC else {
                // I am not the top view controller
                return
            }

            nc.popViewController(animated: animated)
        } else {
            self.dismiss(animated: animated, completion: nil)
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension SKYChatConversationListViewController: UITableViewDelegate, UITableViewDataSource {

    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userConversations.count
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let userConversation = self.userConversations[indexPath.row]
        if let cell = tableView.dequeueReusableCell(withIdentifier: "ConversationCell")
            as? SKYChatConversationTableViewCell {

            cell.conversation = userConversation.conversation
            cell.unreadMessageCount = userConversation.unreadCount

            if let ds = self.dataSource {
                cell.avatarImage = ds.listViewController?(self,
                                                          avatarImageForConversation: userConversation.conversation,
                                                          atIndexPath: indexPath)
            } else {
                let title = userConversation.conversation.title ?? ""
                cell.avatarImage = UIImage.avatarImage(forInitialsOfName: title)
            }

            return cell
        } else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            if let title = userConversation.conversation.title {
                cell.textLabel?.text = title
                cell.textLabel?.textColor = UIColor.black
            } else {
                cell.textLabel?.text = "Untitled"
                cell.textLabel?.textColor = UIColor.lightGray
            }

            return cell
        }
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(75)
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let d = self.delegate {
            let conv = self.userConversations[indexPath.row]
            d.listViewController?(self, didSelectConversation: conv.conversation)
        }
    }
}

// MARK: - Utility Methods

extension SKYChatConversationListViewController {

    open func getUserConversations() -> [SKYUserConversation] {
        return self.userConversations
    }

    open func performQuery() {
        SVProgressHUD.show()
        self.skygear.chatExtension?.fetchUserConversations(completion: { (userConversations, error) in
            SVProgressHUD.dismiss()
            if let err = error {
                self.handleQueryError(error: err)
                return
            }

            if let uc = userConversations {
                self.handleQueryResult(result: uc)
            } else {
                let err = SKYErrorCreator()
                    .error(with: SKYErrorBadResponse,
                           message: "Query does not response UserConversation")
                self.handleQueryError(error: err!)
            }
        })
    }

    open func handleQueryResult(result: [SKYUserConversation]) {
        self.userConversations = result
        self.tableView.reloadData()
    }

    open func handleQueryError(error: Error) {
        SVProgressHUD.showError(withStatus: error.localizedDescription)
    }
}
