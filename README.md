# kubectl-fzf

An interactive kubectl wrapper that uses [fzf](https://github.com/junegunn/fzf) for fuzzy resource selection, making Kubernetes operations more intuitive and faster.

## 🚀 Features

### Interactive Resource Selection
- **Fuzzy search**: Use fzf's powerful fuzzy matching to quickly find resources
- **Visual interface**: Clean, responsive selection interface with keyboard navigation
- **Smart filtering**: Intelligent resource listing based on command context

### Command Support
kubectl-fzf automatically handles resource listing for commands that require specific targets:

- `describe` - Describe specific resources
- `logs` - View logs from pods
- `delete` - Delete specific resources
- `edit` - Edit resource configurations
- `port-forward` - Forward ports from pods/services

### Namespace Operations
- **Current namespace**: Work within your current kubectl context
- **Cross-namespace**: Use `-A` or `--all-namespaces` to search across all namespaces
- **Automatic namespace handling**: Properly formats commands with namespace flags

### Seamless Integration
- **Backward compatibility**: Falls back to original kubectl when `--fzf` flag is not used
- **Command history**: Integrates with zsh command history (commands appear in your shell history)
- **Error handling**: Graceful error messages and validation

## 📋 Prerequisites

- **kubectl**: Kubernetes command-line tool
- **fzf**: Command-line fuzzy finder ([installation guide](https://github.com/junegunn/fzf#installation))
- **zsh**: For optimal command history integration

## 🛠️ Installation

1. **Download the script**:
   ```bash
   curl -O https://raw.githubusercontent.com/codenio/kubectl-fzf/main/kubectl-fzf.sh
   ```

2. **Source the function** in your shell profile (`~/.zshrc`, `~/.bashrc`):
   ```bash
   source /path/to/kubectl-fzf.sh
   ```

3. **Reload your shell**:
   ```bash
   source ~/.zshrc  # or ~/.bashrc
   ```

## 🎯 Usage

### Basic Syntax
```bash
kubectl <command> <resource-type> --fzf [additional-flags]
```

### Examples

#### Describe a Pod
```bash
kubectl describe pod --fzf
```
1. Lists all pods in the current namespace
2. Opens fzf for selection
3. Generates: `kubectl describe pod <selected-pod>`

#### View Logs with Options
```bash
kubectl logs pod --fzf -f --tail=100
```
1. Select a pod via fzf
2. Generates: `kubectl logs <selected-pod> -f --tail=100`

#### Cross-Namespace Operations
```bash
kubectl describe pod --fzf -A
```
1. Lists pods from all namespaces
2. Automatically includes namespace in final command
3. Generates: `kubectl describe pod <selected-pod> -n <namespace>`

#### Delete Resources
```bash
kubectl delete deployment --fzf --cascade=foreground
```
1. Lists deployments for selection
2. Generates: `kubectl delete deployment <selected-deployment> --cascade=foreground`


### Debug Mode
Enable debug output to see how commands are processed:

```bash
kubectl describe pod --fzf --debug
```

Debug output shows:
- Parsed subcommand and object
- Additional flags detected  
- Namespace mode (current vs all)
- List command used for fzf

## 🔧 How It Works

1. **Command Detection**: Detects presence of `--fzf` flag
2. **Smart Listing**: For commands like `describe`, `logs`, `delete`, etc., uses `kubectl get` to list resources
3. **Interactive Selection**: Presents resources in fzf for fuzzy selection
4. **Command Generation**: Builds final kubectl command with selected resource and original flags
5. **History Integration**: Uses `print -rz` to add command to zsh history

## ⚡ Performance Features

- **Optimized parsing**: Efficient flag processing with arrays instead of string concatenation
- **Smart caching**: Minimal external command calls
- **Error-first validation**: Quick validation before expensive operations
- **Parallel-safe**: Proper variable scoping with `local` declarations

## 🛡️ Error Handling

- **Dependency check**: Validates fzf installation
- **Resource validation**: Confirms resources exist before presenting selection
- **Selection validation**: Handles user cancellation and invalid selections
- **Proper error output**: Error messages directed to stderr

## 🔄 Compatibility

### Shell Compatibility
- **Full support**: zsh (with command history integration)
- **Basic support**: bash (without command history integration)

### kubectl Version
Compatible with all modern kubectl versions. The script uses standard kubectl commands and output formats.

### Platform Support
- ✅ macOS
- ✅ Linux  
- ✅ WSL2

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

### Development
To test changes:
```bash
# Enable debug mode
kubectl describe pod --fzf --debug

# Test cross-namespace
kubectl get pod --fzf -A --debug
```

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [fzf](https://github.com/junegunn/fzf) - The fantastic fuzzy finder that makes this possible
- [kubectl](https://kubernetes.io/docs/reference/kubectl/) - The Kubernetes command-line tool
