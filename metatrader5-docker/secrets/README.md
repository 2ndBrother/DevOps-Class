# Runtime secret

`scripts/init.sh` creates `secrets/vnc_password` with an eight-character random
password. The host `secrets` directory is mode `700`; the file is mode `644`
because Docker Compose implements a file-backed secret as a bind mount and does
not remap its owner to the container's non-root UID. Directory permissions keep
other host users from reaching the file, while the isolated `trader` process can
read the mounted copy. The generated file is ignored by Git and the Docker build
context.

The legacy VNC/RFB authentication mechanism only uses eight characters. The
default deployment therefore binds noVNC to host loopback and expects access
through an SSH tunnel.
