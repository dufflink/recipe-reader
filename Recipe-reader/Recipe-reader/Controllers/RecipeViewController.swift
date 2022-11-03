//
//  RecipeViewController.swift
//  text-recognition
//
//  Created by Maxim Skorynin on 15.12.2021.
//

import UIKit

protocol RecipeHandlerDelegate: AnyObject {
    
    func recipeDidHandle(recipeRows: [RecipeRow])
    
}

final class RecipeViewController: UIViewController {
    
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var buttonsStackView: UIStackView!
    
    private let liveTextHandlerView = LiveTextHandlerView()
    private var formattedRecipeModels: [FormattedRecipeModel]?
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        addLiveTextButton()
        
//        let recipeHandler = RecipeHandler()
//        let rows = recipeHandler.handleText("""
//        2 cup hot milk
//        500fl. oz powder
//        8c. low-sodium chicken broth
//        1tsp. fresh thyme leaves
//        """)
//
//        recipeDidHandle(recipeRows: rows)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.insertSubview(liveTextHandlerView, at: 0)
    }
    
    // MARK: - Functins
    
    @IBAction private func customCameraDidPress(_ sender: Any) {
        guard let cameraViewController = Storyboard.cameraViewController else {
            return
        }
        
        cameraViewController.recipeHandlerDelegate = self
        present(cameraViewController, animated: true)
    }
    
    private func configureTableView() {
        tableView.dataSource = self
        tableView.register(UINib(nibName: IngredientRow.identifier, bundle: nil), forCellReuseIdentifier: IngredientRow.identifier)
    }
    
    private func addLiveTextButton() {
        if #available(iOS 15.0, *) {
            liveTextHandlerView.recipeHandlerDelegate = self
            let liveTextCameraAction = UIAction.captureTextFromCamera(responder: liveTextHandlerView, identifier: nil)
            
            let button = RRButton(primaryAction: liveTextCameraAction)
            
            button.setTitle("Live Text", for: .normal)
            button.setImage(nil, for: .normal)
            
            buttonsStackView.insertArrangedSubview(button, at: 0)
        }
    }
    
    @objc private func keyboardCrutch() {
        liveTextHandlerView.becomeFirstResponder()
        self.view.endEditing(true)
    }
    
}

// MARK: - UITable View Data Source

extension RecipeViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return formattedRecipeModels?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = tableView.dequeueReusableCell(withIdentifier: IngredientRow.identifier, for: indexPath) as? IngredientRow
        
        if let model = formattedRecipeModels?[safe: indexPath.row] {
            row?.configure(from: model)
        }
        
        return row ?? UITableViewCell()
    }
    
}

// MARK: - Recipe Handler View Controller Delegate

extension RecipeViewController: RecipeHandlerDelegate {
    
    func recipeDidHandle(recipeRows: [RecipeRow]) {
        formattedRecipeModels = recipeRows.map { FormattedRecipeModel(recipeRow: $0) }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
}
