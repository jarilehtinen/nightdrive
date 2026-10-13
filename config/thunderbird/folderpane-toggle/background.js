// Show/hide the folder pane in the active mail tab.
browser.browserAction.onClicked.addListener(async () => {
  const [tab] = await browser.mailTabs.query({ active: true, currentWindow: true });
  if (tab) {
    await browser.mailTabs.update(tab.id, { folderPaneVisible: !tab.folderPaneVisible });
  }
});
