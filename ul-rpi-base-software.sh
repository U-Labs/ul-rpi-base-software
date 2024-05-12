#!/bin/bash
set -eu
optBaseDir=/opt/ul-install
btopVersion=1.3.0

boldFormat=$(tput bold)
normalFormat=$(tput sgr0)
arch=$(dpkg --print-architecture)
function log() {
	echo "${boldFormat}[${FUNCNAME[1]}] ${normalFormat}$1"
}
function log_nl() {
	echo "${boldFormat}[${FUNCNAME[1]}] ${normalFormat}$1"
	echo
}
function is_gui_os() {
	# https://forums.raspberrypi.com/viewtopic.php?t=327466
	grep -q "stage4" /boot/issue.txt
}

function common_aliases() {
	file=~/.bash_aliases
	if grep -L "alias dc" $file > /dev/null; then
		log "Aliase bereits gesetzt"
	else
		log "Lege allgemeine Aliase an"
		echo "alias dc='docker compose'" >> $file
	fi

	cat $file
	echo
}
function install_apt_silent() {
	package=$1
	log "Installiere $package als Abhängigkeit..."
        sudo apt-get install -y $package > /dev/null
}
function install_if_command_missing() {
	commandToTest=$1
	package=$2
	if command -v $commandToTest > /dev/null; then
		log "Werkzeug $commandToTest existiert bereits"
	else
		install_apt_silent $package
	fi
}
function install_general_requirements() {
	install_if_command_missing git git
}

function install_btop() {
	if command -v btop > /dev/null; then
		log "Btop bereits installiert"
		btop --version
		echo
		return
	fi

	declare -A files
	files[armhf]="btop-arm-linux-musleabi.tbz"
	files[arm64]="btop-aarch64-linux-musl.tbz"
	file=${files["$arch"]}

	cd /tmp
	wget https://github.com/aristocratos/btop/releases/download/v$btopVersion/$file -O btop.tbz
	tar xjf btop.tbz
	cd btop
	bash install.sh
}
function install_fzf() {
	targetDir=~/.fzf
	if test -d $targetDir; then
  		log "Fzf ist bereits installiert"
		fzf --version

		echo "Prüfe entferntes Git-Repository auf Änderungen:"
		cd $targetDir
		git pull
		echo
		return
	fi

	git clone --depth 1 https://github.com/junegunn/fzf.git $targetDir
	~/.fzf/install --all
}
function install_eza() {
	if command -v eza > /dev/null; then
		log "Eza ist bereits installiert"
		eza --version
		echo
		return
	fi

	sudo apt-get  install -y gpg

	sudo mkdir -p /etc/apt/keyrings
	wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
	echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
	sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
	sudo apt-get update
	sudo apt-get install -y eza

cat <<EOF >> ~/.bashrc
alias l="eza -l -F -g -h --icons --group-directories-first"
alias ll="l -T -L 2"
EOF
	. ~/.bashrc
}
function add_ble_sh_config() {
cat <<EOF > ~/.blerc
function ble/prompt/backslash:custom/memoryTime {
  ble/prompt/unit/add-hash '$SECONDS'
  ble/prompt/process-prompt-string "💾$(free -h | grep Mem | awk '{printf $3 "/" $2}')\r⏰\t"
}
bleopt prompt_status_line="🐧$(uname -o) $(uname -r) $(uname -m)\r📟$(dmesg | grep 'Machine model' | awk -F': ' '{print $2}')\r\q{custom/memoryTime}"
bleopt prompt_status_align=$'justify=\r'
# Zeigt die Ausführungszeit & CPU-Last an, wenn der Befehl > 10 ms benötigt hat
bleopt exec_elapsed_mark=$' \\e[94m[↪️[%s 📈%s%%]\e[m'
bleopt exec_elapsed_enabled='usr+sys>=10'
# Exitcode (nur angezeigt, wenn nicht gleich null)
bleopt exec_errexit_mark=$' \e[91m[⚡️RC ➡️ %d]\e[m'
# Blaue Trennlinie zwischen den Befehlen
bleopt prompt_ruler=$'\e[94m-'
EOF
}
function install_ble_sh() {
	bleScript=~/.local/share/blesh/ble.sh
	if [ -f $bleScript ]; then
		log "Ble.sh ist bereits installiert"
		grep _ble_init_version= $bleScript | awk -F'=' '{print $2}'
		echo
		return
	fi

	log "Installiere Abhängigkeiten make, gawk"
	sudo apt-get install -y make gawk > /dev/null

	cd $optBaseDir
	git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git
	make -C ble.sh install PREFIX=~/.local
	echo 'source ~/.local/share/blesh/ble.sh' >> ~/.bashrc
	add_ble_sh_config
	source ~/.bashrc
}
function install_docker() {
	if command -v docker > /dev/null; then
		log "Docker ist bereits installiert"
		docker --version
		docker compose version
		echo
		return
	fi

	# curl -fsSL https://get.docker.com -o install-docker.sh
	log "Installiere Docker Abhängigkeiten"
	sudo apt-get update -qq >/dev/null
	export DEBIAN_FRONTEND=noninteractive 
	sudo apt-get install -y -qq apt-transport-https ca-certificates curl >/dev/null
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL "https://download.docker.com/linux/debian/gpg" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
	codename=$(lsb_release -sc | head -2)
	echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $codename stable" > /etc/apt/sources.list.d/docker.list
	sudo apt-get update -qq >/dev/null
	
	log "Installiere Docker mit Compose"
	sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin
	docker version

	log "Füge $USER zur Docker-Gruppe hinzu (Docker ohne root)"
	sudo usermod -aG docker $USER
	newgrp docker
	docker run hello-world
}
function install_belsoft_java_repos() {
	# https://u-labs.de/portal/aktuelles-java-17-11-und-weitere-ueber-die-paketverwaltung-mit-liberica-jdk-auf-dem-raspberry-pi-und-x86-linux-systemen-installieren/ 
	repoFile=/etc/apt/sources.list.d/bellsoft-liberica.list
	if [ -f $repoFile ]; then
		log "Bellsoft-Repository existiert bereits in $repoFile:"
		cat $repoFile
		return
	fi

	sudo mkdir -p /usr/local/share/keyrings
	wget -q -O key.gpg https://download.bell-sw.com/pki/GPG-KEY-bellsoft
	gpg --no-default-keyring --keyring ./tmp.gpg --import key.gpg
	gpg --no-default-keyring --keyring ./tmp.gpg --export --output bellsoft-liberica.gpg
	sudo mv bellsoft-liberica.gpg /usr/local/share/keyrings
	rm key.gpg tmp.gpg tmp.gpg~

	arch=$(uname -m)
	repoArch=armhf
	if [ "$arch" == "aarch64" ]; then
		repoArch=arm64
	fi

	log "Architektur: $arch - füge $repoArch in $repoFile hinzu"
	echo "deb [arch=$repoArch signed-by=/usr/local/share/keyrings/bellsoft-liberica.gpg] https://apt.bell-sw.com/ stable main" | sudo tee $repoFile
	log "Aktualisiere Paketquellen"
	sudo apt-get update > /dev/null
	log "Folgende APT-Pakete stehen nun zur Verfügung - jeweils mit '-full', '-lite', und '-runtime' Suffix"
	apt-cache search bellsoft-java | awk -F ' - ' '{print $1}' | grep -E -v '(full|lite|runtime)'
}
function ask_supported_minecraft_version() {
	versions=$(curl -s https://hub.spigotmc.org/versions/ | grep -E -o 'href="[^"]+"' | grep -E -o "[0-9]+\.[0-9]+(\.[0-9]+)?(\-[a-z]+[0-9]+)?" | sort -V -r)
	declare -a versionOptions
	for version in $(echo $versions); do
		versionOptions+=( "$version" "Minecraft $version" )
	done

	height=40
	width=80
	choiceHeight=8
	backtitle="U-Labs Tool: Minecraft-Server mit Spigot"
	title="Minecraft Versionsauswahl zur Installation"
	menu="Bitte wähle die Minecraft-Version zur Installation. Dein Client muss die gleiche Version nutzen, um sich verbinden zu können!"
	selectedVersion=$(dialog --keep-tite --backtitle "$backtitle" --title "$title" --menu "$menu" $height $width $choiceHeight "${versionOptions[@]}" 2>&1 >/dev/tty)
	echo $selectedVersion	
}
function install_spigot_minecraft_server() {
        baseDir=$optBaseDir/spigot
	mcVersion=$(ask_supported_minecraft_version)
	clear

	install_belsoft_java_repos
        install_apt_silent bellsoft-java17

        mkdir -p $baseDir
        cd $baseDir

        wget -O BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
	if git config --global --get core.autocrlf; then
		git config --global --unset core.autocrlf
	fi

	if [ -f spigot.jar ]; then
		log "spigot.jar gefunden:"
		ls -lh spigot.jar
		echo "Minecraft-Version: $(spigot_mc_version)"
		return
	fi
	java -jar BuildTools.jar --final-name spigot.jar --rev $mcVersion
	mcVersion=$(spigot_mc_version)
	log "Minecraft-Version: $mcVersion"
	echo $mcVersion > ul-minecraft-version.txt
	prepare_spigot_service $baseDir
	show_spigot_minecraft_usage
}
function spigot_mc_version() {
	mcVersion=$(find . -name spigot-*-SNAPSHOT-bootstrap.jar -printf "%f\n" | awk -F '-' '{print $2}')
	echo $mcVersion
}
function prepare_spigot_service() {
	baseDir=$1
	java -Xms1G -Xmx1G -XX:+UseG1GC -jar spigot.jar nogui --noconsole || true
	serviceFile=/etc/systemd/system/minecraft.service
	sed -i 's/eula=false/eula=true/' eula.txt

cat <<EOF | sudo tee -a $serviceFile
[Unit]
Description=Spigot Minecraft Server
 
[Service]
WorkingDirectory=$baseDir
ExecStart=java -Xms1G -Xmx1G -XX:+UseG1GC -jar spigot.jar nogui
User=$USER
Type=simple
Restart=on-failure
 
[Install]
WantedBy=multi-user.target
EOF
	sudo systemctl daemon-reload
	sudo systemctl enable --now minecraft
	systemctl status minecraft
}
function show_spigot_minecraft_usage() {
	log "Prüfen, ob der MC-Server läuft (Active: active = läuft):"
	log "systemctl status minecraft"
	
	echo
	log "Logs/Protokolle des MC-Server ansehen:"
	log "journalctl -xu minecraft"
	log "Tipp: mit -f (follow) werden neue Logmeldungen automatisch angezeigt"

	echo
	log "MC-Server neu starten:"
	log "sudo systemctl restart minecraft"
}
function install_testssl() {
	appDir=$optBaseDir/testssl
	pathLink=/usr/local/bin/testssl.sh

	if [ -d "$appDir" ]; then
		log "Repo in $appDir bereits vorhanden, prüfe auf Aktualisierungen..."
		wd=$(pwd)
		cd $appDir
		git pull
		cd $wd
	else
		git clone --depth 1 https://github.com/drwetter/testssl.sh.git $appDir
	fi

	if [ ! -f "$pathLink" ]; then
		log "Erzeuge Symbolische Verknüpfung $pathLink"
		sudo ln -s $appDir/testssl.sh $pathLink
	fi

	version=$(grep 'declare -r VERSION=' $appDir/testssl.sh | awk -F'=' '{print substr($2, 2, length($2) - 2)}')
	log "Installierte Version: $version"
	log "Verwendung von testssl: testssl.sh <host>, z.B. testssl.sh u-labs.de"
}

log "Architektur: $arch"
sudo mkdir -p $optBaseDir
sudo chown $USER $optBaseDir
wd=$(pwd)
# Alternative: "whiptail", unterstützt mehr Arten von Dialogen
# https://www.dev-insider.de/dialogboxen-mit-whiptail-erstellen-a-860990/
if ! command -v dialog > /dev/null; then
	install_apt_silent dialog
fi

model=$(dmesg | grep 'Machine model' | awk -F': ' '{print $2}')
title="🧪U-Labs Raspberry Pi Basis-Werkzeuge\n🍓$model "
if is_gui_os; then
	title+="🖥️"
else
	title+="⌨️"
fi
title+="\n\n🔼🔽 Hoch/runter blättern, [Leertaste] aktivieren/deaktivieren, [Tab] wechselt nach unten, [Enter] startet.\n\nWähle aus, welche Komponenten du installieren möchtest:"
# --keep-tite fixt Anzeigefehler beim abbrechen
# https://askubuntu.com/a/684192/650986
cmd=(dialog --keep-tite --separate-output --checklist "$title" 23 76 16)
options=(
	1 "Aliases" on
    2 "Vim" on	
	3 "Btop" on
    4 "Fzf" on
    5 "Eza" on
	6 "Ble.sh" on
 	7 "Docker" off
	8 "testssl.sh" on
	9 "Java (Bellsoft Paketquellen)" off
	10 "Minecraft Server (Spigot)" off
)
choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

# Deckt den Abbruch ab. In diesem Fall sollen die allgemeinen Abhängigkeiten nicht installiert werden.
if [ -z "$choices" ]; then
	cd $wd
	exit 0
fi

install_general_requirements
for choice in $choices
do
    case $choice in
    1)
	    common_aliases
        ;;
	2)
	    install_if_command_missing vim vim
	    ;;
    3)
        install_btop
        ;;
    4)
        install_fzf
    	;;
    5)
        install_eza
        ;;
    6)
        install_ble_sh
        ;;
	7)
	    install_docker
	    ;;
	8)
	    install_testssl
	    ;;
	9)
	    install_belsoft_java_repos
	    ;;
	10)
        install_spigot_minecraft_server
        ;;
    esac
done

cd $wd
echo
log "Installationen abgeschlossen!"
log "Um manche Funktionen nutzen zu können, ist es nötig, dass du dich abmeldest (exit) und neu anmeldest."
