kubectl() {
    # Check if fzf is installed
    if ! command -v fzf &>/dev/null; then
        echo "Error: fzf is not installed. Please install fzf and try again." >&2
        return 1
    fi

    # If --fzf flag is not present, use original kubectl
    if [[ $* != *--fzf* ]]; then
        command kubectl "$@"
        return $?
    fi

    local subcommand="$1"
    local object="$2"
    local -a flags=()
    local use_all_namespaces=false
    local debug_mode=false
    
    # Parse flags more efficiently
    local arg
    for arg in "${@:3}"; do
        case "$arg" in
            --fzf) ;;  # Skip fzf flag
            --debug) debug_mode=true ;;
            -A|--all-namespaces) use_all_namespaces=true ;;
            *) flags+=("$arg") ;;
        esac
    done

    # For commands that need specific resources, use 'get' to list them first
    local list_cmd=("kubectl")
    case "$subcommand" in
        describe|logs|delete|edit|port-forward)
            list_cmd+=("get" "$object")
            ;;
        *)
            list_cmd+=("$subcommand" "$object")
            ;;
    esac
    [[ "$use_all_namespaces" == true ]] && list_cmd+=("-A")

    # Debug output if requested
    if [[ "$debug_mode" == true ]]; then
        echo "subcommand: $subcommand" >&2
        echo "object: $object" >&2
        echo "flags: ${flags[*]}" >&2
        echo "use_all_namespaces: $use_all_namespaces" >&2
        echo "list_cmd: ${list_cmd[*]}" >&2
    fi

    local resource_list
    if ! resource_list=$("${list_cmd[@]}" 2>/dev/null); then
        echo "Error: No resources found for '${list_cmd[*]}'." >&2
        return 1
    fi

    # Use fzf to select resource
    local selection
    if ! selection=$(echo "$resource_list" | fzf --height=50% --layout=reverse --prompt="Select resource: "); then
        echo "No selection made." >&2
        return 1
    fi

    # Parse selection and build final command
    local final_cmd=("kubectl" "$subcommand" "$object")
    
    if [[ "$use_all_namespaces" == true ]]; then
        # For -A flag, we need resource name and namespace
        local resource_name namespace
        read -r namespace resource_name <<< "$(echo "$selection" | awk '{if (NF>=2) print $1, $2; else print "", $1}')"
        
        if [[ -z "$resource_name" ]]; then
            echo "Error: Invalid selection format." >&2
            return 1
        fi
        
        final_cmd+=("$resource_name")
        [[ -n "$namespace" ]] && final_cmd+=("-n" "$namespace")
    else
        # For current namespace, just get resource name
        local resource_name
        resource_name=$(echo "$selection" | awk '{print $1}')
        final_cmd+=("$resource_name")
    fi
    
    # Add additional flags
    final_cmd+=("${flags[@]}")
    
    # Execute the command using print -rz for zsh history
    print -rz -- "${final_cmd[*]}"
}