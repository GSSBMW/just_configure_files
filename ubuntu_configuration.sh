sudo apt-get update

# install and configure Tmux
pushd .; cd ~
sudo apt-get install tmux
wget https://github.com/GSSBMW/just_configure_files/blob/master/.tmux.conf
popd
