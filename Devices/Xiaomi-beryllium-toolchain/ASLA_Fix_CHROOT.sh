echo "--- Fixing Audio (ALSA UCM) ---"
apt-get install -y alsa-ucm-conf
cd /tmp
git clone --depth 1 https://gitlab.com/sdm845-mainline/alsa-ucm-conf.git sdm845-ucm
cp -r sdm845-ucm/ucm2/conf.d/sm845 /usr/share/alsa/ucm2/conf.d/
cp -r sdm845-ucm/ucm2/sm845 /usr/share/alsa/ucm2/
