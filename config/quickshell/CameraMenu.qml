import QtQuick

// Camera in use: the apps using it (PrivacyApps). The bar's camera icon shows only while one is.
PrivacyApps {
    key: "camera"; title: "Camera"; icon: "video"
    signal close()
}
