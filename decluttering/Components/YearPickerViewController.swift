import UIKit

/// "Which year shall we sort?" Swipe sort only ever covers today's date, so the choice is which year of it.
final class YearPickerViewController: UIViewController {

    private let dateText: String
    private let options: [YearOption]
    private let onPick: (YearChoice) -> Void
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(dateText: String, options: [YearOption], onPick: @escaping (YearChoice) -> Void) {
        self.dateText = dateText
        self.options = options
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(from host: UIViewController, dateText: String, options: [YearOption], onPick: @escaping (YearChoice) -> Void) {
        let controller = YearPickerViewController(dateText: dateText, options: options, onPick: onPick)
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        host.present(controller, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = BoothTheme.sheetStyle
        view.backgroundColor = BoothTheme.surface

        let title = UILabel()
        title.text = "Which year shall we sort?"
        title.font = BoothTheme.font(26, .heavy)
        title.textColor = BoothTheme.ink
        title.numberOfLines = 0

        let note = UILabel()
        note.text = "Only photos from \(dateText), one year at a time. A little tidy each day is plenty."
        note.font = BoothTheme.font(14, .semibold)
        note.textColor = BoothTheme.ink.withAlphaComponent(0.7)
        note.numberOfLines = 0

        let header = UIStackView(arrangedSubviews: [title, note])
        header.axis = .vertical
        header.spacing = 6
        header.translatesAutoresizingMaskIntoConstraints = false

        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorColor = BoothTheme.ink.withAlphaComponent(0.12)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension YearPickerViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count + 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.textProperties.font = BoothTheme.font(17, .bold)
        content.textProperties.color = BoothTheme.ink
        content.secondaryTextProperties.font = BoothTheme.font(13, .semibold)
        content.secondaryTextProperties.color = BoothTheme.ink.withAlphaComponent(0.65)
        content.imageProperties.tintColor = BoothTheme.ink

        if indexPath.row == 0 {
            let total = options.reduce(0) { $0 + $1.count }
            content.text = "All years"
            content.secondaryText = "\(total) item\(total == 1 ? "" : "s") from \(dateText)"
            content.image = UIImage(systemName: "calendar")
        } else {
            let option = options[indexPath.row - 1]
            content.text = option.title
            content.secondaryText = option.subtitle
            content.image = UIImage(systemName: "folder.fill")
        }
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.tintColor = BoothTheme.ink
        cell.backgroundColor = BoothTheme.paper.withAlphaComponent(0.6)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let choice: YearChoice = indexPath.row == 0 ? .all : .year(options[indexPath.row - 1].key)
        let pick = onPick
        dismiss(animated: true) { pick(choice) }
    }
}
