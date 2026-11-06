Below is an Ansible-native baseline that matches your requirements: Alpine/APK-aware, OpenRC-aware, idempotent where practical, and structured so you can iterate on it later for k0s/k0sctl.

---

## 1. Relevant Ansible modules for Alpine

For your use case, these are the right building blocks:

- **`community.general.apk`**  
  Alpine’s APK package manager module.

- **`ansible.builtin.raw`**  
  Used only for the one-time Python bootstrap. `raw` does not require Python on the target host.

- **`ansible.builtin.service` with OpenRC**  
  Ansible’s built-in service module can manage OpenRC. I explicitly set:
  ```yaml
  use: openrc
  ```
  If your Ansible version complains about that, remove it and let Ansible auto-detect OpenRC.

- **`ansible.posix.mount`**  
  The clean Ansible-native way to manage `/etc/fstab` entries.

- **`ansible.builtin.file` with `attributes: "+i"`**  
  Native way to set immutable attributes via `chattr`, where supported.

- **`ansible.builtin.lineinfile`**  
  Used to ensure `/etc/modules` contains `bonding` and `simpledrm`.

- **`ansible.builtin.copy` / `ansible.builtin.template`**  
  For static config files and the OpenRC service scripts.

---

## 2. Suggested folder structure

Create a directory, for example `ansible/`, and lay it out like this:

```text
ansible/
├── ansible.cfg
├── inventory.ini
├── requirements.yml
├── site.yml
├── group_vars/
│   └── k0s.yml
└── roles/
    └── alpine_baseline/
        ├── handlers/
        │   └── main.yml
        ├── meta/
        │   └── main.yml
        ├── tasks/
        │   ├── main.yml
        │   ├── packages.yml
        │   ├── kernel_initramfs.yml
        │   ├── kernel_modules.yml
        │   ├── cgroups.yml
        │   └── nfs_mounts.yml
        └── templates/
            └── openrc-optional-mount.j2
```

---

## 3. Files

### `ansible/requirements.yml`

```yaml
---
collections:
  - name: ansible.posix
  - name: community.general
```

Install them with:

```bash
ansible-galaxy collection install -r requirements.yml
```

---

### `ansible/ansible.cfg`

You already have interpreter discovery configured, but this is a sane reference config:

```ini
[defaults]
inventory = inventory.ini
roles_path = roles
interpreter_python = auto_silent
stdout_callback = yaml
retry_files_enabled = False
```

---

### `ansible/inventory.ini`

Replace the IPs with your actual node IPs.

```ini
[k0s]
orion-1 ansible_host=10.1.0.11 ansible_user=root
orion-2 ansible_host=10.1.0.12 ansible_user=root
orion-3 ansible_host=10.1.0.13 ansible_user=root
```

If you prefer to keep `root@<ip>` style entries, that can work, but the above is cleaner.

---

### `ansible/group_vars/k0s.yml`

This file contains the variables specific to your k0s group.

> **Important note:** You asked for `/etc/defaults/grub`. On most systems the conventional path is `/etc/default/grub`. I kept your requested path below as `grub_defaults_path: /etc/defaults/grub`. If you actually meant the usual GRUB defaults file, change it to `/etc/default/grub`.

```yaml
---
# Optional: if interpreter discovery ever gives you trouble, pin Python explicitly.
# Your ansible.cfg already sets interpreter_python = auto_silent, so this is not required.
# ansible_python_interpreter: /usr/bin/python3

baseline_packages:
  - htop
  - screen
  - fastfetch
  - file
  - tree
  - nano

baseline_prerequisite_packages:
  - kmod          # provides modinfo
  - e2fsprogs     # provides chattr/lsattr reliably
  - nfs-utils     # provides mount.nfs / mount.nfs4 helpers
  - cgroups       # OpenRC cgroups service

# You requested /etc/defaults/grub.
# If you meant the usual GRUB location, use: /etc/default/grub
grub_defaults_path: /etc/defaults/grub

grub_defaults_content: |
  GRUB_TIMEOUT=1
  GRUB_DISABLE_SUBMENU=y
  GRUB_DISABLE_RECOVERY=true
  GRUB_CMDLINE_LINUX_DEFAULT="modules=sd-mod,usb-storage,ext4,nvme,simpledrm rootfstype=ext4 fbcon=nodefer console=ttyAMA0,115200 console=tty0"

mkinitfs_conf_path: /etc/mkinitfs/mkinitfs.conf

mkinitfs_conf_content: |
  features="ata base ide scsi usb virtio phy ext4 nvme simpledrm"

simpledrm_modules_path: /etc/mkinitfs/features.d/simpledrm.modules

baseline_kernel_modules:
  - bonding
  - simpledrm

cgroups_service_name: cgroups

optional_nfs_mounts:
  - name: bunker
    path: /mnt/bunker
    src: "10.1.0.2:/mnt/bunker"
    fstype: nfs4
    opts: "noauto,nofail,_netdev"
    service_name: mount-bunker
    description: "Optional NFS mount for bunker"

  - name: stash
    path: /mnt/stash
    src: "10.1.0.2:/mnt/stash"
    fstype: nfs4
    opts: "noauto,nofail,_netdev"
    service_name: mount-stash
    description: "Optional NFS mount for stash"
```

---

### `ansible/site.yml`

This playbook has two plays:

1. Bootstrap Python using `raw`.
2. Apply the Alpine baseline once Python exists.

```yaml
---
- name: Bootstrap Python on Alpine nodes
  hosts: k0s
  gather_facts: false
  tags:
    - bootstrap
  tasks:
    - name: Install python3 with apk via raw
      ansible.builtin.raw: "sh -c 'apk info -e python3 >/dev/null 2>&1 || apk add --no-cache python3'"
      register: bootstrap_python
      changed_when: bootstrap_python.stdout is defined and ('Installing python3' in bootstrap_python.stdout or 'Upgrading python3' in bootstrap_python.stdout)
      failed_when: bootstrap_python.rc is defined and bootstrap_python.rc != 0

- name: Configure Alpine baseline for k0s nodes
  hosts: k0s
  gather_facts: true
  tags:
    - baseline
  roles:
    - alpine_baseline
```

---

### `ansible/roles/alpine_baseline/meta/main.yml`

Optional but useful for `ansible-lint` and role metadata.

```yaml
---
galaxy_info:
  author: you
  description: Alpine baseline for Radxa Orion O6 k0s nodes
  license: MIT
  min_ansible_version: "2.15"
  platforms:
    - name: Alpine
      versions:
        - all

dependencies: []
```

---

### `ansible/roles/alpine_baseline/tasks/main.yml`

```yaml
---
- name: Install APK packages
  ansible.builtin.import_tasks: packages.yml

- name: Configure GRUB and mkinitfs
  ansible.builtin.import_tasks: kernel_initramfs.yml

- name: Configure /etc/modules
  ansible.builtin.import_tasks: kernel_modules.yml

- name: Enable cgroups v2
  ansible.builtin.import_tasks: cgroups.yml

- name: Configure optional NFS mountpoints
  ansible.builtin.import_tasks: nfs_mounts.yml
```

---

### `ansible/roles/alpine_baseline/tasks/packages.yml`

```yaml
---
- name: Install baseline and prerequisite APK packages
  community.general.apk:
    name: "{{ baseline_packages + baseline_prerequisite_packages }}"
    state: present
    update_cache: true
```

---

### `ansible/roles/alpine_baseline/tasks/kernel_initramfs.yml`

This task file does the following:

- Writes your GRUB defaults.
- Writes `/etc/mkinitfs/mkinitfs.conf`.
- Ensures `/etc/mkinitfs/features.d` exists.
- Generates the `simpledrm.modules` file using remote `modinfo`.
- Notifies handlers to rebuild GRUB/initramfs if those tools exist.

```yaml
---
- name: Ensure directory for GRUB defaults exists
  ansible.builtin.file:
    path: "{{ grub_defaults_path | dirname }}"
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Install GRUB defaults
  ansible.builtin.copy:
    dest: "{{ grub_defaults_path }}"
    content: "{{ grub_defaults_content }}"
    owner: root
    group: root
    mode: "0644"
  notify: update grub

- name: Ensure mkinitfs configuration directory exists
  ansible.builtin.file:
    path: "{{ mkinitfs_conf_path | dirname }}"
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Install mkinitfs.conf
  ansible.builtin.copy:
    dest: "{{ mkinitfs_conf_path }}"
    content: "{{ mkinitfs_conf_content }}"
    owner: root
    group: root
    mode: "0644"
  notify: rebuild mkinitfs

- name: Ensure mkinitfs features.d directory exists
  ansible.builtin.file:
    path: "{{ simpledrm_modules_path | dirname }}"
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Generate simpledrm module list
  ansible.builtin.shell: |
    {
      echo simpledrm
      for dep in $(modinfo -F depends simpledrm 2>/dev/null | tr ',' ' '); do
        if modinfo "$dep" >/dev/null 2>&1; then
          echo "$dep"
        fi
      done
    } | sort -u
  args:
    executable: /bin/sh
  register: simpledrm_modules_content
  changed_when: false
  check_mode: false

- name: Install simpledrm.modules
  ansible.builtin.copy:
    dest: "{{ simpledrm_modules_path }}"
    content: |
      {{ simpledrm_modules_content.stdout }}
    owner: root
    group: root
    mode: "0644"
  notify: rebuild mkinitfs
```

The `simpledrm.modules` generation is intentionally implemented as:

1. Read-only remote shell generation.
2. Ansible-managed file copy.

That gives you proper diffing and idempotence. If you instead used your exact script directly with redirection every time, Ansible would have a harder time knowing whether the file changed.

---

### `ansible/roles/alpine_baseline/tasks/kernel_modules.yml`

```yaml
---
- name: Ensure /etc/modules loads required modules
  ansible.builtin.lineinfile:
    path: /etc/modules
    line: "{{ item }}"
    regexp: "^{{ item | regex_escape }}$"
    state: present
    create: true
    owner: root
    group: root
    mode: "0644"
  loop: "{{ baseline_kernel_modules }}"
```

---

### `ansible/roles/alpine_baseline/tasks/cgroups.yml`

```yaml
---
- name: Ensure cgroups OpenRC service package is installed
  community.general.apk:
    name: cgroups
    state: present

- name: Ensure cgroups OpenRC service is enabled and started
  ansible.builtin.service:
    name: "{{ cgroups_service_name }}"
    state: started
    enabled: true
    use: openrc
```

---

### `ansible/roles/alpine_baseline/tasks/nfs_mounts.yml`

This is the mountpoint/fstab/OpenRC part.

Design decisions:

- `ansible.posix.mount` manages `/etc/fstab`.
- Entries use `noauto`, so OpenRC/localmount does not make them boot-critical.
- Directories are created before immutability is applied.
- Immutability is only applied when the path is not currently mounted.
- Each NFS mount gets its own OpenRC service.
- The OpenRC service returns success even if the mount fails, so a failed optional NFS mount does not break the rest of the system.

```yaml
---
- name: Ensure /mnt exists
  ansible.builtin.file:
    path: /mnt
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Stat configured mountpoint paths
  ansible.builtin.stat:
    path: "{{ item.path }}"
  loop: "{{ optional_nfs_mounts }}"
  register: mountpoint_stats

- name: Fail when a mountpoint path exists but is not a directory
  ansible.builtin.assert:
    that:
      - item.stat.isdir
    fail_msg: "{{ item.item.path }} exists but is not a directory"
  loop: "{{ mountpoint_stats.results }}"
  when: item.stat.exists

- name: Create missing mountpoint directories
  ansible.builtin.file:
    path: "{{ item.item.path }}"
    state: directory
    owner: root
    group: root
    mode: "0755"
  loop: "{{ mountpoint_stats.results }}"
  when: not item.stat.exists

- name: Write optional NFS fstab entries
  ansible.posix.mount:
    path: "{{ item.path }}"
    src: "{{ item.src }}"
    fstype: "{{ item.fstype }}"
    opts: "{{ item.opts }}"
    dump: 0
    passno: 0
    state: present
  loop: "{{ optional_nfs_mounts }}"

- name: Check whether each mountpoint is already mounted
  ansible.builtin.shell: grep -q " {{ item.path }} " /proc/mounts 2>/dev/null
  args:
    executable: /bin/sh
  register: mountpoint_active
  changed_when: false
  failed_when: false
  loop: "{{ optional_nfs_mounts }}"

- name: Make unmounted mountpoint directories immutable
  ansible.builtin.file:
    path: "{{ item.item.path }}"
    attributes: "+i"
    state: directory
    owner: root
    group: root
    mode: "0755"
  loop: "{{ mountpoint_active.results }}"
  when: item.rc == 1

- name: Install OpenRC service scripts for optional mounts
  ansible.builtin.template:
    src: openrc-optional-mount.j2
    dest: "/etc/init.d/{{ item.service_name }}"
    owner: root
    group: root
    mode: "0755"
  loop: "{{ optional_nfs_mounts }}"

- name: Enable and start optional mount services
  ansible.builtin.service:
    name: "{{ item.service_name }}"
    state: started
    enabled: true
    use: openrc
  loop: "{{ optional_nfs_mounts }}"
```

---

### `ansible/roles/alpine_baseline/templates/openrc-optional-mount.j2`

```sh
#!/sbin/openrc-run
# {{ ansible_managed }}

description="{{ item.description }}"

depend() {
    after bootmisc localmount networking
    need net
}

start() {
    ebegin "Mounting {{ item.src }} on {{ item.path }}"

    if grep -q " {{ item.path }} " /proc/mounts 2>/dev/null; then
        eend 0
        return 0
    fi

    if timeout 20 mount -t {{ item.fstype }} -o {{ item.opts }} {{ item.src }} {{ item.path }}; then
        eend 0
    else
        ewarn "Optional mount failed: {{ item.path }}"
        eend 0
    fi
}

stop() {
    ebegin "Unmounting {{ item.path }}"

    if grep -q " {{ item.path }} " /proc/mounts 2>/dev/null; then
        umount {{ item.path }} || umount -l {{ item.path }} || true
    fi

    eend 0
}
```

This service intentionally uses `eend 0` even when mounting fails. That means OpenRC will not treat the optional mount failure as a fatal service failure.

---

### `ansible/roles/alpine_baseline/handlers/main.yml`

These handlers only run if the relevant tools exist.

```yaml
---
- name: Update GRUB if grub-mkconfig is available
  ansible.builtin.shell: |
    if command -v grub-mkconfig >/dev/null 2>&1; then
      grub-mkconfig -o /boot/grub/grub.cfg
      echo GRUB_UPDATED
    fi
  args:
    executable: /bin/sh
  register: grub_update_result
  changed_when: "'GRUB_UPDATED' in grub_update_result.stdout"
  listen: update grub

- name: Rebuild initramfs if mkinitfs is available
  ansible.builtin.shell: |
    if command -v mkinitfs >/dev/null 2>&1; then
      mkinitfs
      echo MKINITFS_UPDATED
    fi
  args:
    executable: /bin/sh
  register: mkinitfs_result
  changed_when: "'MKINITFS_UPDATED' in mkinitfs_result.stdout"
  listen: rebuild mkinitfs
```

---

## 4. Optional lint helper files

These are not required, but they make linting quieter.

### `ansible/.yamllint`

```yaml
---
extends: default

rules:
  line-length: disable
  truthy: disable
```

### `ansible/.ansible-lint`

```yaml
---
skip_list:
  - yaml[line-length]
```

---

## 5. Commands to lint and test before running

From the `ansible/` directory:

### Install dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate

python -m pip install ansible ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
```

### Validate inventory

```bash
ansible-inventory -i inventory.ini --list
```

or for one host:

```bash
ansible-inventory -i inventory.ini --host orion-1
```

### Syntax check

```bash
ansible-playbook -i inventory.ini site.yml --syntax-check
```

### Lint

```bash
ansible-lint site.yml roles
yamllint .
```

### Dry-run / check mode

On nodes that already have Python installed:

```bash
ansible-playbook -i inventory.ini site.yml --check --diff --skip-tags bootstrap
```

If the nodes are completely fresh Alpine installs without Python, the Python bootstrap has to run once before the rest can be checked:

```bash
ansible-playbook -i inventory.ini site.yml --tags bootstrap
```

Then dry-run the rest:

```bash
ansible-playbook -i inventory.ini site.yml --check --diff --skip-tags bootstrap
```

### Test against one node first

```bash
ansible-playbook -i inventory.ini site.yml --check --diff --skip-tags bootstrap --limit orion-1
```

Then, when you are comfortable:

```bash
ansible-playbook -i inventory.ini site.yml --limit orion-1
```

Finally:

```bash
ansible-playbook -i inventory.ini site.yml
```

---

## 6. Notes and caveats

### GRUB path

You specified:

```text
/etc/defaults/grub
```

Most systems use:

```text
/etc/default/grub
```

If that was a typo, change:

```yaml
grub_defaults_path: /etc/defaults/grub
```

to:

```yaml
grub_defaults_path: /etc/default/grub
```

### GRUB regeneration

The handler attempts to run:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

only if `grub-mkconfig` exists.

On ARM SBCs, bootloaders are sometimes U-Boot or firmware-specific rather than GRUB. If your Radxa Orion O6 does not actually use GRUB, ignore or remove the GRUB-related parts.

### mkinitfs regeneration

The handler runs:

```bash
mkinitfs
```

only if `mkinitfs` exists.

If your Alpine setup requires a specific kernel flavor or boot path, adjust the handler accordingly.

### NFS kernel modules

`nfs-utils` provides userspace helpers. If your Alpine kernel has NFS client support as modules, you may also need kernel modules such as:

```text
nfs
nfsv4
```

loaded. If mounts fail because NFS modules are missing, add the appropriate module names to `/etc/modules`.

### Immutability and mounted NFS directories

The playbook only applies:

```bash
chattr +i
```

when the mountpoint is not currently mounted.

This avoids trying to set immutable attributes on the remote NFS filesystem itself.

If you later need to change the underlying mountpoint directory, you may need to:

```bash
rc-service mount-bunker stop
chattr -i /mnt/bunker
```

then make your changes and re-apply immutability.

### OpenRC service failure behavior

The generated OpenRC service returns success even when the NFS mount fails.

That satisfies your requirement:

> Do NOT make them mandatory for boot; they may fail and that is fine.

If you later want the service to visibly fail in `rc-status`, change the failure path from:

```sh
eend 0
```

to:

```sh
eend 1
```

but keep in mind that doing so makes the service state failed, even though it still will not necessarily stop unrelated services.
