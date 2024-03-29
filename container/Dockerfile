ARG OSNAME="perl"
ARG OSLABEL="5"

FROM ${OSNAME}:${OSLABEL}

# syntax=docker/dockerfile:1
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    apt-file \
    diffutils  \
    git \
    less \
    libanyevent-perl \
    libclass-refresh-perl \
    libcommon-sense-perl \
    libcompiler-lexer-perl \
    libcoro-perl \
    libdata-dump-perl \
    libfile-slurp-perl \
    libfile-spec-native-perl \
    libhtml-tiny-perl \
    libio-aio-perl \
    libjson-perl \
    liblist-moreutils-perl \
    libmoose-perl \
    libobject-insideout-perl \
    libpadwalker-perl \
    libperl-critic-perl \
    libreadonly-perl \
    libreadonlyx-perl \
    libregexp-assemble-perl \
    libscalar-list-utils-perl \
    libspreadsheet-parseexcel-perl \
    libspreadsheet-parsexlsx-perl \
    libtext-csv-perl \
    libtimedate-perl \
    libxml-twig-perl \
    lighttpd \
    locales \
    locales-all \
    man \
    manpages \
    patch \
    perl \
    perl-doc \
    perltidy \
    procps \
    rsync \
    ssh \
    sudo \
    tmux \
    zsh

# TODO - Consider using Carton
RUN --mount=type=cache,target=/root/.cpanm,sharing=locked \
    cpanm \
    common::sense \
    Date::Parse \
    File::Slurp \
    HTML::Tiny \
    List::MoreUtils \
    Object::InsideOut \
    Perl::Critic \
    Perl::LanguageServer \
    Perl::Tidy \
    Readonly \
    Readonly::XS \
    Spreadsheet::ParseXLSX

RUN --mount=type=cache,target=/root/.cpanm,sharing=locked \
    cpanm \
    Devel::NYTProf \
    Perl::Critic::TooMuchCode

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
#COPY userhome/ /home/"$USER_NAME"/
#COPY userhome/.ssh/ /root/.ssh/

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
