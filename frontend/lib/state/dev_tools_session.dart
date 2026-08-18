class DevToolsSession {
  DevToolsSession._();
  static final DevToolsSession instance = DevToolsSession._();

  bool _unlocked = false;
  bool get isUnlocked => _unlocked;

  void unlock() {
    _unlocked = true;
  }

  void lock() {
    _unlocked = false;
  }
}
