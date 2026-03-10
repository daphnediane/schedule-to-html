# Coro-6.57-c23.patch


This patch is from https://src.fedoraproject.org/rpms/perl-Coro/blob/rawhide/f/Coro-6.57-c23.patch

## Log for the patch

    * Mon Aug 11 2025 Michal Josef Špaček <mspacek@redhat.com> - 6.570-23
    - Fix C23 build

## License of the Coro rpm source has:

    * Coro/libcoro:    GPL-2.0-or-later OR BSD-2-Clause
    * Rest of package: GPL-1.0-or-later OR Artistic-1.0-Perl


## Coro-6.57 License:

    This module is licensed under the same terms as perl itself.
    Please note that Coro/libcoro comes with its own license.

## Coro/libcoro license:

    Copyright (c) 2000-2009 Marc Alexander Lehmann <schmorp@schmorp.de>
    Redistribution and use in source and binary forms, with or without modifica-
    tion, are permitted provided that the following conditions are met:
    1.  Redistributions of source code must retain the above copyright notice,
        this list of conditions and the following disclaimer.
    2.  Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.
    THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
    WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MER-
    CHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
    EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPE-
    CIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
    PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
    OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
    WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTH-
    ERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
    OF THE POSSIBILITY OF SUCH DAMAGE.
    Alternatively, the following files carry an additional notice that
    explicitly allows relicensing under the GPLv2: coro.c, coro.h.
