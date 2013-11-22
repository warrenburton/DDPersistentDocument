//
//  DDPersistentDocument.h
//
//  Created by Warren Burton on 06/05/2013.
//  WTFPL Licensed
// ----------------
// Use at your own risk. Modify and redistribute freely
//


#import "DDPersistentDocument.h"


static NSString *StoreWrapperName = @"StoreContent";
static NSString *PStoreFileName = @"persistentStore";

#pragma mark setFileURL override

@interface NSPersistentDocument (FileWrapperSuport)

- (void)simpleSetFileURL:(NSURL *)fileURL;

@end

@implementation NSPersistentDocument (FileWrapperSuport)

// Forwards the message to NSDocument's setFileURL: (skips NSPersistentDocument's implementation).
- (void)simpleSetFileURL:(NSURL *)fileURL {
    
    [super setFileURL:fileURL];
    
}

@end

#pragma mark private interface

@interface DDPersistentDocument () {
    
    NSManagedObjectContext *publiccontext;
    
    NSFileWrapper *filewrapper;
    
}

@property (strong) NSFileWrapper *documentWrapper;


@end


@implementation DDPersistentDocument


-(void)makeWindowControllers {
    
    
    //create window controllers or alternatively override windowNibName
    
}


+(BOOL)autosavesInPlace
{
    return YES;
}


#pragma mark -
#pragma mark URL management

- (void)setFileURL:(NSURL *)fileURL {
	
    NSURL *originalFileURL = [self storeURLFromBundleURL:[self fileURL]];
    
    if (originalFileURL != nil) {
        
        NSPersistentStoreCoordinator *psc = [[self managedObjectContext] persistentStoreCoordinator];
        
        id store = [psc persistentStoreForURL:originalFileURL];
        
        if (store != nil) {
            
            [psc setURL:[self storeURLFromBundleURL:fileURL] forPersistentStore:store];
        }
    }
    [self simpleSetFileURL:fileURL];
}


- (NSURL *)storeURLFromBundleURL:(NSURL *)bundleURL {
    
    if (!bundleURL) {
        return nil;
    }
    
    NSURL *stage1 = [bundleURL URLByAppendingPathComponent:StoreWrapperName];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[stage1 path]] == NO) {
        
        DLog(@"create subdir at %@",[stage1 path]);
        
        NSError *error = NULL;
        
        //BOOL res = [[NSFileManager defaultManager] createDirectoryAtURL:stage1 withIntermediateDirectories:YES attributes:nil error:&error];
        BOOL res = [[NSFileManager defaultManager] createDirectoryAtPath:[stage1 path] withIntermediateDirectories:YES attributes:nil error:&error];
        
        if (!res) {
            DLog(@"*** error:create subdir at %@",error);
        }
        
    }
    
    NSURL *stage2 = [stage1 URLByAppendingPathComponent:PStoreFileName];
    
    return stage2;
}






#pragma mark -


-(void)moveToURL:(NSURL *)url completionHandler:(void (^)(NSError *))completionHandler
{
    
    NSURL *originalURL = self.fileURL;
    
    DLog(@"move doc %@ from (%@) to (%@)",self,originalURL,url);
    
    NSError *error = NULL;
    
    if (originalURL) {
        
        NSFileCoordinator *fileco = [[NSFileCoordinator alloc] initWithFilePresenter:self];
        
        [fileco coordinateWritingItemAtURL:originalURL
                                   options:NSFileCoordinatorWritingForMoving
                                     error:&error
                                byAccessor:^(NSURL *newURL){
                                    
                                    NSFileManager *fman = [[NSFileManager alloc] init];
                                    
                                    NSError *internalerror = NULL;
                                    
                                    BOOL result = [fman moveItemAtURL:originalURL toURL:url error:&internalerror];
                                    
                                    if (!result) {
                                        DLog(@"file move err = [%@]",[internalerror localizedDescription])
                                    }
                                    else {
                                        
                                        self.fileURL = url;
                                        
                                        [fman removeItemAtURL:originalURL error:NULL];
                                    }
                                    
                                    if (completionHandler) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            completionHandler(internalerror);
                                        });
                                    }
                                    
                                }];
    }
    else {
        
        [super moveToURL:url completionHandler:completionHandler];
        
        return;
    }
    
    
    
    if (error && completionHandler) {
        completionHandler(error);
    }
    
}

-(NSDictionary *)storeOptionsForURL:(NSURL *)aurl {
    
    return nil;
    
}


-(BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error
{
    DLog(@"**** conf psc for url - %@",url);
    
    BOOL res = [super configurePersistentStoreCoordinatorForURL:url ofType:fileType modelConfiguration:configuration storeOptions:storeOptions error:error];
    
    if(!res)
    {
        DLog(@"conf psc err %@",*error);
    }
    return res;
}


-(BOOL)storeExistsForURL:(NSURL *)aurl
{
    for (NSPersistentStore *store in self.managedObjectContext.persistentStoreCoordinator.persistentStores) {
        
        if([store.URL isEqualTo:aurl]) {
            
            return YES;
            
        }
    }
    
    return NO;
    
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)error {
	
    DLog(@"read from URL - %@",absoluteURL);
    
    BOOL success = NO;
    
    self.documentWrapper = [[NSFileWrapper alloc] initWithURL:absoluteURL options:NSFileWrapperReadingImmediate error:error];
    
    NSFileWrapper *dataStore = [[self.documentWrapper fileWrappers] objectForKey:StoreWrapperName];
	
    if (dataStore != nil) {
        
        NSString *path = [[absoluteURL path] stringByAppendingPathComponent:[dataStore filename]];
        
        NSURL *storeURL = [[NSURL fileURLWithPath:path] URLByAppendingPathComponent:PStoreFileName];
        
        success = [self configurePersistentStoreCoordinatorForURL:storeURL ofType:typeName
                                               modelConfiguration:nil storeOptions:nil error:error];
    }
	
    
    return success;
}


-(void)removePersistentStoresNotForURL:(NSURL *)aurl
{
    NSArray *stores = [self.managedObjectContext.persistentStoreCoordinator.persistentStores copy];
    
    for (NSPersistentStore *store in  stores) {
        
        if (![store.URL isEqualTo:aurl]) {
            
            [self.managedObjectContext.persistentStoreCoordinator removePersistentStore:store error:NULL];
            
        }
        
    }
}

- (BOOL)writeSafelyToURL:(NSURL *)inAbsoluteURL ofType:(NSString *)inTypeName forSaveOperation:(NSSaveOperationType)inSaveOperation error:(NSError **)outError {
    
    BOOL success = YES;
    
    NSURL *originalURL = [self fileURL];
    
    if (inSaveOperation == NSSaveAsOperation || inSaveOperation == NSAutosaveElsewhereOperation) {
        
        BOOL isDuplicateOperation = (inSaveOperation == NSAutosaveElsewhereOperation && originalURL);
        
        BOOL isRenameOperation = (inSaveOperation == NSSaveAsOperation && self.autosavedContentsFileURL);
		
        NSURL *storeURL = [self storeURLFromBundleURL:inAbsoluteURL];
        
        NSError *ferror = NULL;
        
        self.documentWrapper = [[NSFileWrapper alloc] initWithURL:inAbsoluteURL options:NSFileWrapperReadingImmediate error:&ferror];
        
        if (ferror) {
            
            *outError = ferror;
            return NO;
            
        }
        
        if ( isRenameOperation || isDuplicateOperation ) {
            
            NSURL *sourceURL = isRenameOperation? [self storeURLFromBundleURL:self.autosavedContentsFileURL]:[self storeURLFromBundleURL:originalURL];
            
            NSError *merror = NULL;
            
            NSPersistentStoreCoordinator *psc = [[self managedObjectContext] persistentStoreCoordinator];
            
            NSPersistentStore *sourcestore = [psc persistentStoreForURL:sourceURL];
            
            
            success = ([psc migratePersistentStore:sourcestore toURL:storeURL options:nil withType:[self persistentStoreTypeForFileType:inTypeName] error:&merror] != nil);
            
            if (!success) {
                *outError = merror;
                DLog(@"migrate store error = %@",merror);
                return NO;
            }
            
        }
        
        if (![self storeExistsForURL:storeURL]) {
            
            NSError *pscerr = NULL;
            
            success = [self configurePersistentStoreCoordinatorForURL:storeURL ofType:inTypeName modelConfiguration:nil storeOptions:nil error:&pscerr];
            
            if (!success) {
                DLog(@"configure psc error = %@",pscerr);
                *outError = pscerr;
                return NO;
                
            }
            
        }
        
        NSError *ferror2 = NULL;
        
        NSFileWrapper *cdwrapper = [[NSFileWrapper alloc] initWithURL:storeURL options:NSFileWrapperReadingImmediate error:&ferror2];
        
        if (ferror2) {
            DLog(@"unable to write to core data file wrapper = %@",ferror2);
            *outError = ferror2;
            return NO;
        }
        
        cdwrapper.preferredFilename = PStoreFileName;
        
        [self.documentWrapper addFileWrapper:cdwrapper];
        
        
    }
	else {
        
        
        NSURL *currentWriteStore = [self storeURLFromBundleURL:inAbsoluteURL];
        
        if (![self storeExistsForURL:currentWriteStore]) {
            
            NSError *pscerr = NULL;
            
            success = [self configurePersistentStoreCoordinatorForURL:currentWriteStore ofType:inTypeName modelConfiguration:nil storeOptions:nil error:&pscerr];
            
            if (!success) {
                DLog(@"configure psc (for dup op) error = %@",pscerr);
                *outError = pscerr;
                return NO;
                
            }
            
            [self removePersistentStoresNotForURL:currentWriteStore];
        }
        
    }
    

    if (success == YES) {
        
        success = [[self managedObjectContext] save:outError];
    }
    
    if (success == YES) {
        
        NSDictionary *fileAttributes = [self fileAttributesToWriteToURL:inAbsoluteURL ofType:inTypeName forSaveOperation:inSaveOperation originalContentsURL:originalURL error:outError];
        
        [[NSFileManager defaultManager] setAttributes:fileAttributes ofItemAtPath:[inAbsoluteURL path] error:outError];
        
    }
    else {
        DLog(@"moc save error  - %@",*outError);
    }
	
    return success;
}



#pragma mark -
#pragma mark Revert
- (BOOL)revertToContentsOfURL:(NSURL *)inAbsoluteURL ofType:(NSString *)inTypeName error:(NSError **)outError {
    
    NSPersistentStoreCoordinator *psc = [[self managedObjectContext] persistentStoreCoordinator];
    
    id store = [psc persistentStoreForURL:[self storeURLFromBundleURL:inAbsoluteURL]];
    
    if (store) {
        [psc removePersistentStore:store error:outError];
    }
    
    return [super revertToContentsOfURL:inAbsoluteURL ofType:inTypeName error:outError];
}


-(NSManagedObjectContext *)managedObjectContext
{
    
    if (!publiccontext) {
        
        NSPersistentStoreCoordinator *psc = [[super managedObjectContext] persistentStoreCoordinator];
        
        publiccontext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        
        publiccontext.persistentStoreCoordinator = psc;
        
        self.undoManager = publiccontext.undoManager;
        
    }
    
    return publiccontext;
    
    
}



@end


