# flutter_diff_action
Run Flutter commands with diff checking capabilities.
Supports both standard Flutter commands and Melos-based workflows.

Originally created by [Ajay Kumar] & [Dipangshu Roy].

The following sections show how to configure this action.

## Specifying Flutter command

```yaml
steps:
  - name: Clone repository
    uses: actions/checkout@v4
  - name: Set up Flutter
    uses: subosito/flutter-action@v2
    with:
      flutter-version: 3.19.6

  - name: Run Flutter command
    uses: ProjectAJ14/flutter_diff_action@v1
    with:
      command: "flutter test"
      use-melos: false
```

## Specifying Flutter command with melos

```yaml
steps:
  - name: Clone repository
    uses: actions/checkout@v4
  - name: Set up Flutter
    uses: subosito/flutter-action@v2
    with:
      flutter-version: 3.19.6
      
  - name: Install Melos
    run: dart pub global activate melos
    
  - name: Run Flutter command
    uses: ProjectAJ14/flutter_diff_action@v1
    with:
      command: "flutter test"
      use-melos: true
```

[Ajay Kumar]: https://github.com/ProjectAJ14
[Dipangshu Roy]: https://github.com/droyder7

## Contributing

We welcome contributions in various forms:

- Proposing new features or enhancements.
- Reporting and fixing bugs.
- Engaging in discussions to help make decisions.
- Improving documentation, as it is essential.
- Sending Pull Requests is greatly appreciated!

A big thank you to all our contributors! 🙌

<br></br>
<div align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=ProjectAJ14/flutter_diff_action"  alt="contributors"/>
  </a>
</div>