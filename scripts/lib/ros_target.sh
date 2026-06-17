#!/usr/bin/env bash
# OS codename + ROS 2 distro selection for the Delatometry installer.

ROS_TARGET="${ROS_TARGET:-}"
OS_CODENAME="${OS_CODENAME:-}"
DETECTED_OS_CODENAME=""
DETECTED_OS_PRETTY=""

detect_os_codename() {
  . /etc/os-release
  DETECTED_OS_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  DETECTED_OS_PRETTY="${PRETTY_NAME:-${NAME:-Unknown}}"
  echo "$DETECTED_OS_CODENAME"
}

default_ros_target_for_codename() {
  local codename="${1:-}"
  case "$codename" in
    bookworm) echo "bookworm-jazzy" ;;
    noble) echo "noble-jazzy" ;;
    jammy) echo "jammy-humble" ;;
    trixie) echo "trixie-rolling" ;;
    *) echo "noble-jazzy" ;;
  esac
}

ros_target_label() {
  case "$1" in
    bookworm-jazzy) echo "Debian 12 Bookworm + ROS 2 Jazzy (Raspberry Pi OS / test boards)" ;;
    noble-jazzy) echo "Ubuntu 24.04 Noble + ROS 2 Jazzy (production default)" ;;
    jammy-humble) echo "Ubuntu 22.04 Jammy + ROS 2 Humble" ;;
    bookworm-rolling) echo "Debian 12 Bookworm + ROS 2 Rolling" ;;
    noble-kilted) echo "Ubuntu 24.04 Noble + ROS 2 Kilted" ;;
    custom) echo "Custom OS codename + ROS distro" ;;
    *) echo "$1" ;;
  esac
}

apply_ros_target_profile() {
  local profile="$1"
  case "$profile" in
    bookworm-jazzy)
      OS_CODENAME=bookworm
      ROS_DISTRO=jazzy
      ROS_INSTALL_SOURCE_FALLBACK=1
      ;;
    noble-jazzy)
      OS_CODENAME=noble
      ROS_DISTRO=jazzy
      ;;
    jammy-humble)
      OS_CODENAME=jammy
      ROS_DISTRO=humble
      ;;
    bookworm-rolling)
      OS_CODENAME=bookworm
      ROS_DISTRO=rolling
      ;;
    noble-kilted)
      OS_CODENAME=noble
      ROS_DISTRO=kilted
      ;;
    custom)
      : "${OS_CODENAME:=$(detect_os_codename)}"
      : "${ROS_DISTRO:=jazzy}"
      ;;
    *)
      _install_die "Unknown ROS target profile: $profile"
      ;;
  esac

  ROS_TARGET="$profile"
  if [ "$OS_CODENAME" = "bookworm" ] && [ "${ROS_INSTALL_SOURCE_FALLBACK:-0}" = "1" ]; then
    ROS_SETUP="${ROS_SOURCE_WS:-$HOME/ros2_${ROS_DISTRO}_ws}/install/setup.bash"
  else
    ROS_SETUP="/opt/ros/${ROS_DISTRO}/setup.bash"
  fi
  export OS_CODENAME ROS_DISTRO ROS_SETUP ROS_TARGET ROS_INSTALL_SOURCE_FALLBACK
}

load_ros_target_from_config() {
  local env_file="${1:-/etc/default/delatometry}"
  [ -f "$env_file" ] || return 1

  local saved_distro saved_codename saved_setup
  saved_distro="$(grep -E '^DELATOMETRY_ROS_DISTRO=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"')"
  saved_codename="$(grep -E '^DELATOMETRY_OS_CODENAME=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"')"
  saved_setup="$(grep -E '^DELATOMETRY_ROS_SETUP=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"')"

  [ -n "$saved_distro" ] || return 1
  ROS_DISTRO="$saved_distro"
  OS_CODENAME="${saved_codename:-$(detect_os_codename)}"
  ROS_SETUP="${saved_setup:-/opt/ros/${ROS_DISTRO}/setup.bash}"
  ROS_TARGET="${ROS_TARGET:-saved}"
  export OS_CODENAME ROS_DISTRO ROS_SETUP ROS_TARGET
  _install_log "Loaded ROS target from $env_file: ${OS_CODENAME} + ROS 2 ${ROS_DISTRO}"
  return 0
}

show_ros_target_dialog() {
  if ! interactive_ui_enabled; then
    local detected
    detected="$(detect_os_codename)"
    apply_ros_target_profile "$(default_ros_target_for_codename "$detected")"
    return 0
  fi
  ensure_whiptail

  local detected default_profile choice rc=0
  detected="$(detect_os_codename)"
  default_profile="$(default_ros_target_for_codename "$detected")"

  if [ -n "${ROS_TARGET:-}" ] && [ "${ROS_TARGET}" != "saved" ]; then
    apply_ros_target_profile "$ROS_TARGET"
    return 0
  fi

  if [ -n "${OS_CODENAME:-}" ] && [ -n "${ROS_DISTRO:-}" ]; then
    ROS_SETUP="/opt/ros/${ROS_DISTRO}/setup.bash"
    ROS_TARGET=custom
    _install_log "Using ROS target from environment: ${OS_CODENAME} + ROS 2 ${ROS_DISTRO}"
    return 0
  fi

  _ros_target_radiolist_flag() {
    if [ "$1" = "$default_profile" ]; then echo ON; else echo OFF; fi
  }

  choice="$(
    whiptail --title "ROS 2 install target" --radiolist \
      "Detected: ${DETECTED_OS_PRETTY} (codename: ${detected:-unknown})\nSelect apt OS codename + ROS 2 distro (UP/DOWN, SPACE, ENTER):" \
      22 88 6 \
      "bookworm-jazzy" "Debian 12 Bookworm + ROS 2 Jazzy — Pi OS / test boards" "$(_ros_target_radiolist_flag bookworm-jazzy)" \
      "noble-jazzy" "Ubuntu 24.04 Noble + ROS 2 Jazzy — production default" "$(_ros_target_radiolist_flag noble-jazzy)" \
      "jammy-humble" "Ubuntu 22.04 Jammy + ROS 2 Humble" "$(_ros_target_radiolist_flag jammy-humble)" \
      "bookworm-rolling" "Debian Bookworm + ROS 2 Rolling" "$(_ros_target_radiolist_flag bookworm-rolling)" \
      "noble-kilted" "Ubuntu Noble + ROS 2 Kilted" "$(_ros_target_radiolist_flag noble-kilted)" \
      "custom" "Enter OS codename and ROS distro manually" "$(_ros_target_radiolist_flag custom)" \
      3>&1 1>&2 2>&3
  )" || rc=$?
  whiptail_handle_cancel "$rc"
  [ -n "${choice:-}" ] || _install_die "ROS target not selected"

  if [ "$choice" = "custom" ]; then
    rc=0
    OS_CODENAME="$(
      whiptail --title "OS codename (apt)" --inputbox \
        "Debian/Ubuntu codename for ros-apt-source.\nDetected on this machine: ${detected}" \
        12 72 "${detected:-bookworm}" 3>&1 1>&2 2>&3
    )" || rc=$?
    whiptail_handle_cancel "$rc"
    rc=0
    ROS_DISTRO="$(
      whiptail --title "ROS 2 distro" --inputbox \
        "ROS 2 distribution name (e.g. jazzy, humble, rolling):" \
        10 72 "jazzy" 3>&1 1>&2 2>&3
    )" || rc=$?
    whiptail_handle_cancel "$rc"
    apply_ros_target_profile custom
    return 0
  fi

  apply_ros_target_profile "$choice"

  if [ -n "$detected" ] && [ "$detected" != "$OS_CODENAME" ]; then
    rc=0
    whiptail --title "Cross-target install" --yesno \
      "This machine reports codename '${detected}' but you selected apt target '${OS_CODENAME}' + ROS 2 ${ROS_DISTRO}.\n\nContinue anyway?" \
      12 74 || rc=$?
    whiptail_handle_cancel "$rc"
    if [ "$rc" -ne 0 ]; then
      _install_die "Cross-target install declined"
    fi
  fi
}

select_ros_target() {
  local mode="${1:-scratch}"

  if [ -n "${ROS_TARGET:-}" ] && [ "${ROS_TARGET}" != "saved" ]; then
    apply_ros_target_profile "$ROS_TARGET"
    _install_log "ROS target (ROS_TARGET): $(ros_target_label "$ROS_TARGET")"
    return 0
  fi

  if [ -n "${OS_CODENAME:-}" ] && [ -n "${ROS_DISTRO:-}" ]; then
    ROS_SETUP="/opt/ros/${ROS_DISTRO}/setup.bash"
    ROS_TARGET=custom
    _install_log "ROS target (env): ${OS_CODENAME} + ROS 2 ${ROS_DISTRO}"
    return 0
  fi

  if [ "$mode" = "rebuild" ]; then
    if load_ros_target_from_config; then
      return 0
    fi
    local detected
    detected="$(detect_os_codename)"
    apply_ros_target_profile "$(default_ros_target_for_codename "$detected")"
    _install_log "ROS target (rebuild default): ${OS_CODENAME} + ROS 2 ${ROS_DISTRO}"
    return 0
  fi

  if interactive_ui_enabled; then
    show_ros_target_dialog
    _install_log "ROS target (dialog): ${OS_CODENAME} + ROS 2 ${ROS_DISTRO} — $(ros_target_label "$ROS_TARGET")"
    return 0
  fi

  local detected
  detected="$(detect_os_codename)"
  apply_ros_target_profile "$(default_ros_target_for_codename "$detected")"
  _install_log "ROS target (auto): ${OS_CODENAME} + ROS 2 ${ROS_DISTRO} (detected ${detected})"
}
