ARG OSNAME="almalinux"
ARG OSLABEL="9"

FROM ${OSNAME}:${OSLABEL}

# Core packages
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf install -y \
    diffutils \
    dnf-plugins-core \
    epel-release \
    git \
    hostname \
    man-pages \
    patch \
    perl \
    perl-App-cpanminus \
    perl-CPAN \
    perl-File-Slurp \
    perl-PathTools \
    perl-Pod-Perldoc \
    perl-TimeDate \
    perl-XML-Parser \
    procps-ng \
    rsync \
    sudo \
    tmux \
    zsh

# EPEL packages
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf install -y \
    lighttpd \
    perl-CryptX \
    perl-Regexp-Assemble \
    perl-Text-CSV

# EPEL/CRB packages
# Some are EPEL but with CRB depends
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf install -y \
    --enablerepo=crb \
    perl-App-cpanminus \
    perl-common-sense \
    perl-Perl-Critic \
    perl-Readonly \
    perl-Spreadsheet-ParseExcel \
    perl-Spreadsheet-XLSX \
    perltidy

RUN --mount=type=cache,target=/root/.cpanm,sharing=locked \
    cpanm \
    HTML::Tiny \
    Object::InsideOut \
    Spreadsheet::ParseXLSX \
    XML::Twig

ARG USER_NAME=devel
ARG USER_ID=1000
ARG USER_SHELL="/bin/bash"
ARG GROUP_NAME=${USER_NAME}
ARG GROUP_ID=${USER_ID}

# Create the user
RUN groupadd --gid "${GROUP_ID}" "${GROUP_NAME}" \
    && useradd --uid "${USER_ID}" --gid "${GROUP_ID}" -m "${USER_NAME}" -s "${USER_SHELL}" \
    && mkdir -m 0640 -p /etc/sudoers.d \
    && echo "${USER_NAME}" ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/"${USER_NAME}" \
    && chmod 0440 /etc/sudoers.d/"${USER_NAME}"
COPY userhome/ /home/"$USER_NAME"/
COPY userhome/.ssh/ /root/.ssh/

# Create workspace tree
RUN mkdir -p \
    /home/"$USER_NAME"/.ssh \
    /home/"$USER_NAME"/bin \
    /workspaces \
    && chmod -R go-rwx /root \
    && chown -R "$USER_NAME":"$GROUP_NAME" \
    /home/"$USER_NAME" \
    /workspaces \
    && chmod -R go-rwx /home/"$USER_NAME"/.ssh \
    && chmod -R u+rwx /home/"$USER_NAME"/bin \
    && git config --system push.default simple \
    && git config --system init.defaultBranch main

USER ${USER_NAME}
