import Quickshell.Io

// A command whose output is delivered as the signal result(text).
// If `script` is set, it is run with bash, stderr is merged into the output and exitCode is set.
// Pass secrets (e.g. a password) in the `environment` field, not on the command line.
Process {
    id: p
    property string script: ""
    property int exitCode: 0
    signal result(string text)

    command: script !== "" ? ["bash", "-c", "exec 2>&1\n" + script + "\necho \"__EXIT:$?\""] : []

    stdout: StdioCollector {
        onStreamFinished: {
            let t = text
            if (p.script !== "") {
                const m = t.match(/__EXIT:(\d+)\s*$/)
                p.exitCode = m ? parseInt(m[1]) : -1
                t = t.replace(/__EXIT:\d+\s*$/, "")
            }
            p.result(t)
        }
    }
}
