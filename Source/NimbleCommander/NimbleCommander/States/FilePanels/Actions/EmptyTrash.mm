#include "EmptyTrash.h"
#include "Delete.h"
#include "../PanelController.h"

namespace nc::panel::actions {

EmptyTrash::EmptyTrash(nc::utility::NativeFSManager &_nat_fsman) : m_NativeFSManager{_nat_fsman}
{
}

NSURL *EmptyTrash::CurrentTrashURL(PanelController *_target) const
{
    std::string path = _target.currentDirectoryPath;
    auto vol = m_NativeFSManager.VolumeFromPath(path);

    if( vol && vol->interfaces.has_trash ) {
        NSURL *volumeURL = vol->verbose.url;
        NSError *error = nil;
        NSURL *trashURL = [[NSFileManager defaultManager] URLForDirectory:NSTrashDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:volumeURL
                                                                   create:NO
                                                                    error:&error];
        return trashURL && !error ? trashURL : nil;
    }
    return nil;
}

NSArray<NSURL *> *EmptyTrash::TrashFilePaths(PanelController *_target) const
{
    NSURL *trashURL = EmptyTrash::CurrentTrashURL(_target);
    if( !trashURL )
        return nil;

    NSError *error = nil;
    NSArray<NSURL *> *contents =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:trashURL
                                      includingPropertiesForKeys:nil
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:&error];
    return contents.count && !error ? contents : nil;
}

bool EmptyTrash::Predicate(PanelController *_target) const
{
    return EmptyTrash::TrashFilePaths(_target) != nil;
}

void EmptyTrash::Perform(PanelController *_target, id _sender) const
{
    (void)_sender;
    std::string path = _target.currentDirectoryPath;
    auto vol = m_NativeFSManager.VolumeFromPath(path);
    NSArray<NSURL *> *contents = EmptyTrash::TrashFilePaths(_target);

    for( NSURL *url in contents ) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    }

    [_target hintAboutFilesystemChange];
}

} // namespace nc::panel::actions
