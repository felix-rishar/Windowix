# SPDX-License-Identifier: GPL-2.0-only

# Unlike the kernel space, exported headers are written in standard C.
#  - Forbid C++ style comments
#  - Use '__inline__', '__asm__' instead of 'inline', 'asm'
#
# -std=c90 (equivalent to -ansi) catches the violation of those.
# We cannot go as far as adding -Wpedantic since it emits too many warnings.
UAPI_CFLAGS := -std=c90 -Wall -Werror=implicit-function-declaration

# In theory, we do not care -m32 or -m64 for header compile tests.
# It is here just because CONFIG_CC_CAN_LINK is tested with -m32 or -m64.
UAPI_CFLAGS += $(filter -m32 -m64 --target=%, $(KBUILD_CPPFLAGS) $(KBUILD_CFLAGS))

# USERCFLAGS might contain sysroot location for CC.
UAPI_CFLAGS += $(USERCFLAGS)

override c_flags = $(UAPI_CFLAGS) -Wp,-MMD,$(depfile) -I $(obj) -I $(srctree)/usr/dummy-include

# List of headers that are currently excluded from testing
no-header-test := \
	asm/ucontext.h drm/vmwgfx_drm.h \
	linux/am437x-vpfe.h linux/coda.h linux/cyclades.h linux/errqueue.h \
	linux/hdlc/ioctl.h linux/ivtv.h linux/matroxfb.h linux/omap3isp.h \
	linux/omapfb.h linux/patchkey.h linux/phonet.h linux/sctp.h \
	linux/sysctl.h linux/usb/audio.h linux/v4l2-mediabus.h \
	linux/v4l2-subdev.h linux/videodev2.h linux/vm_sockets.h \
	sound/asequencer.h sound/asoc.h sound/asound.h sound/compress_offload.h \
	sound/emu10k1.h sound/sfnt_info.h xen/evtchn.h xen/gntdev.h xen/privcmd.h

# More headers are broken in some architectures
ifneq ($(filter $(SRCARCH), arc powerpc),)
	no-header-test += linux/bpf_perf_event.h
endif

ifneq ($(filter $(SRCARCH), sparc),)
	no-header-test += asm/uctx.h asm/fbio.h
endif

# asm-generic/*.h is used by asm/*.h, and should not be included directly
no-header-test += asm-generic/%

# Generate test targets for headers
always-y := $(patsubst $(obj)/%.h,%.hdrtest, $(wildcard $(obj)/*.h))

# Include the header twice to detect missing include guard.
quiet_cmd_hdrtest = HDRTEST $<
      cmd_hdrtest = \
		$(CC) $(c_flags) -fsyntax-only -x c /dev/null \
			$(if $(filter-out $(no-header-test), $*.h), -include $< -include $<); \
		$(PERL) $(src)/headers_check.pl $(obj) $<; \
		touch $@

$(obj)/%.hdrtest: $(obj)/%.h FORCE
	$(call if_changed_dep,hdrtest)

# Cleanup rule
clean-files += $(filter-out Makefile headers_check.pl, $(notdir $(wildcard $(obj)/*)))
