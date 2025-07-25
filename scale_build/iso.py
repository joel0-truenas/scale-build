import glob
import logging
import os
import platform

from .bootstrap.bootstrapdir import CdromBootstrapDirectory
from .exceptions import CallError
from .image.bootstrap import clean_mounts, setup_chroot_basedir, umount_tmpfs_and_clean_chroot_dir
from .image.iso import install_iso_packages, make_iso_file
from .image.manifest import get_image_version, iso_file_path, update_file_path
from .utils.logger import LoggingContext
from .utils.paths import LOG_DIR, RELEASE_DIR
from .config import TRUENAS_VENDOR


logger = logging.getLogger(__name__)


def build_iso():
    try:
        return build_impl()
    finally:
        clean_mounts()


def build_impl():
    clean_mounts()
    for f in glob.glob(os.path.join(LOG_DIR, 'cdrom*')):
        os.unlink(f)

    if not os.path.exists(update_file_path()):
        raise CallError('Missing rootfs image. Run \'make update\' first.')

    logger.debug('Bootstrapping CD chroot [ISO] (%s/cdrom-bootstrap.log)', LOG_DIR)
    with LoggingContext('cdrom-bootstrap', 'w'):
        cdrom_bootstrap_obj = CdromBootstrapDirectory()
        cdrom_bootstrap_obj.setup()
        setup_chroot_basedir(cdrom_bootstrap_obj)

    image_version = get_image_version(vendor=TRUENAS_VENDOR)
    logger.debug('Image version identified as %r', image_version)
    logger.debug('Installing packages [ISO] (%s/cdrom-packages.log)', LOG_DIR)
    try:
        with LoggingContext('cdrom-packages', 'w'):
            install_iso_packages()

        logger.debug('Creating ISO file [ISO] (%s/cdrom-iso.log)', LOG_DIR)
        with LoggingContext('cdrom-iso', 'w'):
            make_iso_file()
    finally:
        umount_tmpfs_and_clean_chroot_dir()

    logger.info('Success! CD/USB: %s', os.path.relpath(iso_file_path(image_version)))
