package ftp.server

public class CommandInfo {
    let label: String

    public init(label: String) {
        this.label = label
    }

    public func getLabel() {
        return this.label
    }
}
