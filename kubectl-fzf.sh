kubectl() {
    # kubectl-fzf: Interactive kubectl with fuzzy finder
    # Usage: kubectl <command> <resource> [options] --fzf
    # Examples: 
    # kubectl describe pod : -n kube-system
    # kubectl logs pod -f --fzf
    # kubectl delete deploy : -A

    # Check for fzf dependency
    if ! command -v fzf &>/dev/null; then
        echo "Error: fzf is not installed. Please install fzf and try again." >&2
        return 1
    fi

    # Pass through to original kubectl if --fzf not used
    if [[ $* != *--fzf* && $* != *:* ]]; then
        command kubectl "$@"
        return $?
    fi

    # Parse command: kubectl describe pod --fzf -f → subcommand=describe, object=pod, flags=(-f)
    # Special case: kubectl logs --fzf → subcommand=logs, object="", flags=()
    local subcommand="$1"              # describe, logs, delete, etc.
    local object="$2"                  # pod, deployment, service, etc.
    local -a flags=()                  # additional flags to pass through
    local use_all_namespaces=false     # -A flag detected
    unset -v namespace                 # namespace
    local next_is_namespace=false      # next arg is namespace
    local use_namespace=false          # -n flag detected
    local start_index=3                # where to start processing remaining args
    local debug_mode=false             # --debug flag detected
    
    
    # Separate fzf flags from kubectl flags
    # Example: --fzf --debug -f -A → debug_mode=true, use_all_namespaces=true, flags=(-f)
    local arg
    for arg in "${@:$start_index}"; do
        if [[ "$next_is_namespace" == true ]]; then
            namespace="$arg"
            next_is_namespace=false
            use_namespace=true
            flags+=("$arg")
            continue
        fi
        case "$arg" in
            --fzf|:) ;;                         # skip trigger flag --fzf or :
            --debug) debug_mode=true ;;         # enable debug output
            -A|--all-namespaces) 
                use_all_namespaces=true
                ;; # cross-namespace
            -n|--namespace) 
                next_is_namespace=true 
                flags+=("$arg")
                ;; # next arg is namespace
            *) flags+=("$arg") ;;               # pass through to kubectl
        esac
    done

    # Build listing command: describe pod → kubectl get pod, get pod → kubectl get pod
    local list_cmd=("kubectl")
    case "$subcommand" in
        logs) 
            list_cmd+=("get" "pods")            # logs always uses pods
            ;;
        describe|delete|edit)
            list_cmd+=("get" "$object")         # use 'get' to list resources first
            ;;
        *)
            list_cmd+=("$subcommand" "$object") # use command as-is
            ;;
    esac

    # handle namespaces
    if [[ "$use_all_namespaces" == true ]]; then
        # use all namespace
        list_cmd+=("-A")
    elif [[ "$use_namespace" == true ]]; then
        # use passed namespace
        list_cmd+=("-n" "$namespace")
    fi

    # Debug output
    if [[ "$debug_mode" == true ]]; then
        echo "=== Debug: $subcommand $object → ${list_cmd[*]} ${flags[*]} ===" >&2
        
        if [[ "$use_all_namespaces" == true ]]; then
            echo "=== Debug: use_all_namespaces : $use_all_namespaces ===" >&2
        fi
        if [[ "$use_namespace" == true ]]; then
            echo "=== use_namespace             : $use_namespace ===" >&2
            echo "=== Debug: namespace          : $namespace ===" >&2
        fi
        echo "=== Debug: flags              : ${flags[*]} ===" >&2
        echo "=== Debug: list_cmd           : ${list_cmd[*]} ===" >&2
    fi

    # Get resource list from kubectl
    local resource_list
    if ! resource_list=$("${list_cmd[@]}" 2>/dev/null); then
        echo "Error: No resources found for '${list_cmd[*]}'." >&2
        return 1
    fi

    # Show fzf selector: my-pod-123, my-pod-456 → user selects → my-pod-123
    local selection
    if ! selection=$(echo "$resource_list" | fzf --height=50% --layout=reverse --prompt="Select resource: "); then
        echo "No selection made." >&2
        return 1
    fi

    # Build final command: kubectl describe pod my-pod-123 -n kube-system
    local final_cmd=("kubectl" "$subcommand" "$object")
    
    if [[ "$use_all_namespaces" == true ]]; then
        # Parse -A output: "kube-system my-pod-123" → resource=my-pod-123, namespace=kube-system
        local resource_name namespace
        read -r namespace resource_name <<< "$(echo "$selection" | awk '{if (NF>=2) print $1, $2; else print "", $1}')"
        
        if [[ -z "$resource_name" ]]; then
            echo "Error: Invalid selection format." >&2
            return 1
        fi
        
        final_cmd+=("$resource_name")
        [[ -n "$namespace" ]] && final_cmd+=("-n" "$namespace")
    else
        # use current namespace
        local resource_name
        resource_name=$(echo "$selection" | awk '{print $1}')
        final_cmd+=("$resource_name")
    fi
    
    # Add user flags: kubectl describe pod my-pod-123 -o yaml
    final_cmd+=("${flags[@]}")
    
    # Put command in zsh history for user to execute
    print -rz -- "${final_cmd[*]}"
}