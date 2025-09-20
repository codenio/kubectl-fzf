kubectl() {
    # kubectl-fzf: Interactive kubectl with fuzzy finder
    # Usage: kubectl <command> <resource> --fzf [options]
    # Examples: 
    # kubectl describe pod --fzf 
    # kubectl logs pod --fzf -f | kubectl delete deploy --fzf -A

    # Check for fzf dependency
    if ! command -v fzf &>/dev/null; then
        echo "Error: fzf is not installed. Please install fzf and try again." >&2
        return 1
    fi

    # Pass through to original kubectl if --fzf not used
    if [[ $* != *--fzf* ]]; then
        command kubectl "$@"
        return $?
    fi

    # Parse command: kubectl describe pod --fzf -f → subcommand=describe, object=pod, flags=(-f)
    # Special case: kubectl logs --fzf → subcommand=logs, object="", flags=()
    local subcommand="$1"              # describe, logs, delete, etc.
    local object="$2"                  # pod, deployment, service, etc.
    local -a flags=()                  # additional flags to pass through
    local use_all_namespaces=false     # -A flag detected
    local debug_mode=false             # --debug flag detected
    local start_index=3                # where to start processing remaining args
    
    # Handle logs --fzf case (no resource type specified)
    if [[ "$subcommand" == "logs" && "$object" == "--fzf" ]]; then
        object=""                       # no object specified for logs
        start_index=3                   # start processing from --fzf
    fi
    
    # Separate fzf flags from kubectl flags
    # Example: --fzf --debug -f -A → debug_mode=true, use_all_namespaces=true, flags=(-f)
    local arg
    for arg in "${@:$start_index}"; do
        case "$arg" in
            --fzf) ;;                           # skip trigger flag
            --debug) debug_mode=true ;;         # enable debug output
            -A|--all-namespaces) use_all_namespaces=true ;; # cross-namespace
            *) flags+=("$arg") ;;               # pass through to kubectl
        esac
    done

    # Build listing command: describe pod → kubectl get pod, get pod → kubectl get pod
    local list_cmd=("kubectl")
    case "$subcommand" in
        logs)
            list_cmd+=("get" "pods")            # logs always uses pods
            ;;
        describe|delete|edit|port-forward)
            if [[ "$object" == "--fzf" ]]; then
                echo "Error: Resource type required. Usage: kubectl $subcommand <resource> --fzf" >&2
                return 1
            fi
            list_cmd+=("get" "$object")         # use 'get' to list resources first
            ;;
        *)
            list_cmd+=("$subcommand" "$object") # use command as-is
            ;;
    esac
    [[ "$use_all_namespaces" == true ]] && list_cmd+=("-A")

    # Debug output
    if [[ "$debug_mode" == true ]]; then
        echo "=== Debug: $subcommand $object → ${list_cmd[*]} ===" >&2
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
    local final_object="$object"
    local final_cmd=("kubectl" "$subcommand" "$final_object")
    
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
        # Parse current namespace output: "my-pod-123" → resource=my-pod-123
        local resource_name
        resource_name=$(echo "$selection" | awk '{print $1}')
        final_cmd+=("$resource_name")
    fi
    
    # Add user flags: kubectl describe pod my-pod-123 -o yaml
    final_cmd+=("${flags[@]}")
    
    # Put command in zsh history for user to execute
    print -rz -- "${final_cmd[*]}"
}