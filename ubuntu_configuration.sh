sudo apt-get update

# install and configure ctags
sudo apt-get install ctags
wget -P ~ https://github.com/GSSBMW/just_configure_files/blob/master/.ctags

# install and configure vim
sudo apt-get install vim
git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
wget -P ~ https://github.com/GSSBMW/just_configure_files/blob/master/.vimrc

# install and configure Tmux
sudo apt-get install tmux
wget -P ~ https://github.com/GSSBMW/just_configure_files/blob/master/.tmux.conf

