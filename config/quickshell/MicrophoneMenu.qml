import QtQuick

// Microphone in use: the apps recording (PrivacyApps). The bar's microphone icon shows only while one is.
PrivacyApps {
    key: "mic"; title: "Microphone"; icon: "mic"
    signal close()
}
