//
//  TLSManager.m
//  LocalRadio
//
//  Created by Douglas Ward on 12/15/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

#import "TLSManager.h"
#import "AppDelegate.h"
#import "LocalRadioAppSettings.h"
#import "NSFileManager+DirectoryLocations.h"
#import "DDKeychain_LocalRadio.h"

@implementation TLSManager

// ============================================================================================
//
// ============================================================================================

- (NSString *)tlsDirectoryPath
{
    NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];
    NSString * tlsDirectoryPath = [applicationSupportDirectoryPath stringByAppendingPathComponent:@"tls"];
    return tlsDirectoryPath;
}

// ============================================================================================
//
// ============================================================================================

- (void)openModalSheet
{
    [self performSelectorOnMainThread:@selector(openModalSheetOnMainThread) withObject:NULL waitUntilDone:NO];
}

// ============================================================================================
//
// ============================================================================================

- (void)openModalSheetOnMainThread
{
    if (self.modalSheetIsOpen == NO)
    {
        self.modalSheetIsOpen = YES;
        [self.appDelegate.generatingKeysAndCertificatesProgressIndicator startAnimation:self];
        [self.appDelegate.window beginSheet:self.appDelegate.generatingKeysAndCertificatesSheetWindow  completionHandler:^(NSModalResponse returnCode) {
        }];
    }
}

// ============================================================================================
//
// ============================================================================================

- (void)closeModalSheet
{
    [self performSelectorOnMainThread:@selector(closeModalSheetOnMainThread) withObject:NULL waitUntilDone:NO];
}

// ============================================================================================
//
// ============================================================================================

- (void)closeModalSheetOnMainThread
{
    if (self.modalSheetIsOpen == YES)
    {
        [self.appDelegate.generatingKeysAndCertificatesProgressIndicator stopAnimation:self];
        [self.appDelegate.generatingKeysAndCertificatesSheetWindow.sheetParent endSheet:self.appDelegate.generatingKeysAndCertificatesSheetWindow returnCode:NSModalResponseOK];
        self.modalSheetIsOpen = NO;
    }
}

// ============================================================================================
//
// ============================================================================================

- (void)configureCertificates
{
    // configure a Certificate Authoritory and generate self-signed certificates for Icecast server and source client
    // per https://www.adfinis-sygroup.ch/blog/en/openssl-x509-certificates/
    
    self.modalSheetIsOpen = NO;
    
    NSString * tlsDirectoryPath = [self tlsDirectoryPath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:tlsDirectoryPath])
    {
        NSError *err = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:tlsDirectoryPath
                withIntermediateDirectories:YES attributes:nil error:&err])
        {
            NSLog(@"IcecastController - configureCertificates - Error creating tlsDirectoryPath: %@", err);
        }
    }

    NSString * caKeyFileName = @"LocalRadioCA.key";    // Certificate Authority key
    NSString * caKeyFilePath = [tlsDirectoryPath stringByAppendingPathComponent:caKeyFileName];
    BOOL caKeyExists = [[NSFileManager defaultManager] fileExistsAtPath:caKeyFilePath];

    NSString * caCertificateFileName = @"LocalRadioCA.pem";    // Certificate Authority certificate
    NSString * caCertificateFilePath = [tlsDirectoryPath stringByAppendingPathComponent:caCertificateFileName];
    BOOL caCertificateExists = [[NSFileManager defaultManager] fileExistsAtPath:caCertificateFilePath];

    NSString * serverKeyFileName = @"LocalRadioServer.key";    // https/Icecast server key
    NSString * serverKeyFilePath = [tlsDirectoryPath stringByAppendingPathComponent:serverKeyFileName];
    BOOL serverKeyExists = [[NSFileManager defaultManager] fileExistsAtPath:serverKeyFilePath];

    NSString * serverCertificateSigningRequestFileName = @"LocalRadioServer.csr";    // Icecast Server CSR
    NSString * serverCertificateSigningRequestFilePath = [tlsDirectoryPath stringByAppendingPathComponent:serverCertificateSigningRequestFileName];
    BOOL serverCertificateSigningRequestExists = [[NSFileManager defaultManager] fileExistsAtPath:serverCertificateSigningRequestFilePath];

    NSString * serverCertificateFileName = @"LocalRadioServer.pem";   // certificate only, key not included
    NSString * serverCertificateFilePath = [tlsDirectoryPath stringByAppendingPathComponent:serverCertificateFileName];
    BOOL serverCertificateExists = [[NSFileManager defaultManager] fileExistsAtPath:serverCertificateFilePath];

    NSString * serverComboCertificateFileName = @"LocalRadioServerCombo.pem";   // combined key and certificate for Icecast TLS
    NSString * serverComboCertificateFilePath = [tlsDirectoryPath stringByAppendingPathComponent:serverComboCertificateFileName];
    BOOL serverComboCertificateExists = [[NSFileManager defaultManager] fileExistsAtPath:serverComboCertificateFilePath];
    
    NSString * serverCertificateWrapperFileName = @"LocalRadioServer.p12";   // combined key and certificate for Keychain
    NSString * serverCertificateWrapperFilePath = [tlsDirectoryPath stringByAppendingPathComponent:serverCertificateWrapperFileName];
    BOOL serverCertificateWrapperExists = [[NSFileManager defaultManager] fileExistsAtPath:serverCertificateWrapperFilePath];

    NSString * serverCertificateChainFileName = @"LocalRadioServerChain.pem";
    NSString * serverCertificateChainFilePath = [tlsDirectoryPath stringByAppendingPathComponent:serverCertificateChainFileName];

    if (caKeyExists == NO)
    {
        // create the Certificate Authority key and certificate signing request
        [self openModalSheet];
        [self createCAKey:caKeyFilePath];
        caCertificateExists = NO;
        serverKeyExists = NO;
        serverCertificateSigningRequestExists = NO;
        serverCertificateExists = NO;
    }

    if (caCertificateExists == NO)
    {
        // create the Certificate Authority certificate
        [self openModalSheet];
        [self createCACertificate:caCertificateFilePath key:caKeyFilePath];
        serverKeyExists = NO;
        serverCertificateSigningRequestExists = NO;
        serverCertificateExists = NO;
    }

    if (serverKeyExists == NO)
    {
        // create the Icecast server key and certificate signing request
        [self openModalSheet];
        [self createIcecastServerKey:serverKeyFilePath];
        serverCertificateExists = NO;
    }

    if (serverCertificateExists == NO)
    {
        // create the Icecast server certificate
        [self openModalSheet];
        [self createIcecastServerCSR:serverCertificateSigningRequestFilePath serverKey:serverKeyFilePath];
        [self createIcecastServerCertificate:serverCertificateFilePath
         csr:serverCertificateSigningRequestFilePath caCertificate:caCertificateFilePath caKey:caKeyFilePath];
    }
    
    if (serverComboCertificateExists == NO)
    {
        // create the Icecast server certificate
        [self openModalSheet];
        [self createIcecastServerComboCertificate:serverComboCertificateFilePath
         key:serverKeyFilePath certificate:serverCertificateFilePath];
    }
    
    if (serverCertificateWrapperExists == NO)
    {
        // create the Icecast server certificate wrapper and import into Keychain
        [self openModalSheet];
        [self createIcecastServerCertificateWrapper:serverCertificateWrapperFilePath
         key:serverKeyFilePath certificate:serverCertificateFilePath
         caCertificate:caCertificateFilePath certificateChain:serverCertificateChainFilePath];
    }
    
    [self closeModalSheet];
}

// ============================================================================================
//
// ============================================================================================

- (void)createCAKey:(NSString *)keyFilePath
{
    // openssl genrsa -des3 -out LocalRadioCA.key 2048

    NSLog(@"IcecastController - createCAKey:%@", keyFilePath);

    NSError * removeKeyFileError;
    [NSFileManager.defaultManager removeItemAtPath:keyFilePath error:&removeKeyFileError];

    NSString * openSSLPath = @"/usr/bin/openssl";
    
    NSString * icecastServerSourcePassword = [self.appDelegate.localRadioAppSettings valueForKey:@"IcecastServerSourcePassword"];
    NSString * passphrase = [NSString stringWithFormat:@"pass:%@", icecastServerSourcePassword];
    
    NSArray * openSSLTaskArgsArray = [NSArray arrayWithObjects:
            @"genrsa",
            @"-des3",
            @"-out",
            keyFilePath,
            @"-passout",
            passphrase,
            //@"-subj",
            //subjectString,
            @"2048",
            NULL];

    NSString * openSSLTaskArgsString = [openSSLTaskArgsArray componentsJoinedByString:@" "];
    
    NSLog(@"Launching openssl NSTask: \"%@\" \"%@\"", openSSLPath, openSSLTaskArgsString);
    
    NSTask * openSSLCSRTask = [[NSTask alloc] init];
    openSSLCSRTask.launchPath = openSSLPath;
    openSSLCSRTask.arguments = openSSLTaskArgsArray;

    [openSSLCSRTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

    //IcecastController * weakSelf = self;
    __block BOOL taskDone = NO;
    
    [openSSLCSRTask setTerminationHandler:^(NSTask* task)
    {
        NSLog(@"LocalRadio IcecastController enter createCertificateAuthority openssl terminationHandler, PID=%d", task.processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"LocalRadio IcecastController createCertificateAuthority - openssl terminationStatus 0");
        }
        else
        {
            NSLog(@"LocalRadio IcecastController createCertificateAuthority - openssl terminationStatus %d", task.terminationStatus);
        }
        
        taskDone = YES;
    }];
    
    [openSSLCSRTask launch];

    while (taskDone == NO)
    {
        usleep(5000);
    }
}

// ============================================================================================
//
// ============================================================================================

- (void)createCACertificate:(NSString *)caCertificateFilePath key:(NSString *)keyFilePath
{
    // openssl req -x509 -new -nodes -key LocalRadioCA.key -sha256 -days 1825 -out LocalRadioCA.pem
    
    NSLog(@"IcecastController - createCACertificate:%@", caCertificateFilePath);

    NSError * removeCertificateFileError;
    [NSFileManager.defaultManager removeItemAtPath:caCertificateFilePath error:&removeCertificateFileError];

    NSString * openSSLPath = @"/usr/bin/openssl";

    NSString * extFilePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"x509.ext"];
    
    NSString * bonjourName = [self localHostString];

    NSString * countryCode = @"US";
    NSString * stateCode = @"US";
    NSString * locationName = @"LocalRadio";
    NSString * organizationName = @"LocalRadio";
    NSString * unitName = @"LocalRadio";
    NSString * commonName = bonjourName;
    
    NSString * subjectString = [NSString stringWithFormat:@"/C=%@/ST=%@/L=%@/O=%@/OU=%@/CN=%@", countryCode, stateCode, locationName, organizationName, unitName, commonName];

    NSString * icecastServerSourcePassword = [self.appDelegate.localRadioAppSettings valueForKey:@"IcecastServerSourcePassword"];
    NSString * passphrase = [NSString stringWithFormat:@"pass:%@", icecastServerSourcePassword];

    NSArray * openSSLTaskArgsArray = [NSArray arrayWithObjects:
            @"req",
            @"-x509",
            @"-new",
            //@"-nodes",
            @"-key",
            keyFilePath,
            @"-sha256",
            @"-days",
            @"1825",
            @"-out",
            caCertificateFilePath,
            @"-subj",
            subjectString,
            @"-passin",
            passphrase,
            NULL];

    
    NSString * openSSLTaskArgsString = [openSSLTaskArgsArray componentsJoinedByString:@" "];
    
    NSLog(@"Launching openssl NSTask: \"%@\" \"%@\"", openSSLPath, openSSLTaskArgsString);
    
    NSTask * openSSLCATask = [[NSTask alloc] init];
    openSSLCATask.launchPath = openSSLPath;
    openSSLCATask.arguments = openSSLTaskArgsArray;

    [openSSLCATask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

    //IcecastController * weakSelf = self;
    __block BOOL taskDone = NO;
    
    [openSSLCATask setTerminationHandler:^(NSTask* task)
    {
        NSLog(@"LocalRadio IcecastController enter createCertificateAuthority openssl terminationHandler, PID=%d", task.processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"LocalRadio IcecastController createCertificateAuthority - openssl terminationStatus 0");
        }
        else
        {
            NSLog(@"LocalRadio IcecastController createCertificateAuthority - openssl terminationStatus %d", task.terminationStatus);
        }
        
        taskDone = YES;
    }];
    
    [openSSLCATask launch];

    while (taskDone == NO)
    {
        usleep(5000);
    }
}

// ============================================================================================
//
// ============================================================================================

- (void)createIcecastServerKey:(NSString *)icecastServerKeyFilePath
{
    // openssl genrsa -out MacName.local 2048

    NSLog(@"IcecastController - createIcecastServerKey:%@", icecastServerKeyFilePath);

    NSError * removeKeyFileError;
    [NSFileManager.defaultManager removeItemAtPath:icecastServerKeyFilePath error:&removeKeyFileError];
    
    NSString * openSSLPath = @"/usr/bin/openssl";
 
    NSArray * openSSLTaskArgsArray = [NSArray arrayWithObjects:
            @"genrsa",
            @"-out",
            icecastServerKeyFilePath,
            @"2048",
            NULL];
    
    NSString * openSSLTaskArgsString = [openSSLTaskArgsArray componentsJoinedByString:@" "];
    
    NSLog(@"Launching openssl NSTask: \"%@\" \"%@\"", openSSLPath, openSSLTaskArgsString);
    
    NSTask * openSSLCSRTask = [[NSTask alloc] init];
    openSSLCSRTask.launchPath = openSSLPath;
    openSSLCSRTask.arguments = openSSLTaskArgsArray;

    [openSSLCSRTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

    //IcecastController * weakSelf = self;
    __block BOOL taskDone = NO;
    
    [openSSLCSRTask setTerminationHandler:^(NSTask* task)
    {
        NSLog(@"LocalRadio IcecastController enter createCertificateAuthority openssl terminationHandler, PID=%d", task.processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"LocalRadio IcecastController createCertificateAuthority - openssl terminationStatus 0");
        }
        else
        {
            NSLog(@"LocalRadio IcecastController createCertificateAuthority - openssl terminationStatus %d", task.terminationStatus);
        }
        
        taskDone = YES;
    }];
    
    [openSSLCSRTask launch];

    while (taskDone == NO)
    {
        usleep(5000);
    }
}

// ============================================================================================
//
// ============================================================================================

- (void)createIcecastServerCSR:(NSString *)icecastServerCertificateSigningRequestFilePath serverKey:(NSString *)icecastServerKeyFilePath
{
    // openssl req -new -key Icecast.key -out Icecast.csr

    NSLog(@"IcecastController - createIcecastServerCSR:%@", icecastServerCertificateSigningRequestFilePath);

    NSError * removeCSRFileError;
    [NSFileManager.defaultManager removeItemAtPath:icecastServerCertificateSigningRequestFilePath error:&removeCSRFileError];

    NSString * openSSLPath = @"/usr/bin/openssl";
 
    NSString * bonjourName = [self localHostString];

    NSString * countryCode = @"US";
    NSString * stateCode = @"US";
    NSString * locationName = @"LocalRadio";
    NSString * organizationName = @"LocalRadio";
    NSString * unitName = @"LocalRadio";
    NSString * commonName = bonjourName;
    
    NSString * subjectString = [NSString stringWithFormat:@"/C=%@/ST=%@/L=%@/O=%@/OU=%@/CN=%@", countryCode, stateCode, locationName, organizationName, unitName, commonName];

    NSArray * openSSLTaskArgsArray = [NSArray arrayWithObjects:
            @"req",
            @"-new",
            @"-key",
            icecastServerKeyFilePath,
            @"-out",
            icecastServerCertificateSigningRequestFilePath,
            @"-subj",
            subjectString,
            NULL];
    
    NSString * openSSLTaskArgsString = [openSSLTaskArgsArray componentsJoinedByString:@" "];
    
    NSLog(@"Launching openssl NSTask: \"%@\" \"%@\"", openSSLPath, openSSLTaskArgsString);
    
    NSTask * openSSLCSRTask = [[NSTask alloc] init];
    openSSLCSRTask.launchPath = openSSLPath;
    openSSLCSRTask.arguments = openSSLTaskArgsArray;

    [openSSLCSRTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

    //IcecastController * weakSelf = self;
    __block BOOL taskDone = NO;
    
    [openSSLCSRTask setTerminationHandler:^(NSTask* task)
    {
        NSLog(@"LocalRadio IcecastController enter createCertificateAuthority openssl terminationHandler, PID=%d", task.processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"LocalRadio IcecastController createCertificateAuthority - openssl terminationStatus 0");
        }
        else
        {
            NSLog(@"LocalRadio IcecastController createCertificateAuthority - openssl terminationStatus %d", task.terminationStatus);
        }
        
        taskDone = YES;
    }];
    
    [openSSLCSRTask launch];

    while (taskDone == NO)
    {
        usleep(5000);
    }
}

// ============================================================================================
//
// ============================================================================================

- (void)createIcecastServerCertificate:(NSString *)icecastServerCertificateFilePath csr:(NSString *)icecastServerCertificateSigningRequestFilePath caCertificate:(NSString *)caCertificateFilePath caKey:(NSString *)caRSAKeyFilePath
{
    // openssl x509 -req -in LocalRadio.csr -CA LocalRadioCA.pem -CAkey LocalRadioCA.key -CAcreateserial -out LocalRadio.crt -days 1825 -sha256 -extfile x509.ext

    NSLog(@"IcecastController - createIcecastServerCertificate:%@", icecastServerCertificateFilePath);

    NSError * removeCertificateFileError;
    [NSFileManager.defaultManager removeItemAtPath:icecastServerCertificateFilePath error:&removeCertificateFileError];

    NSString * openSSLPath = @"/usr/bin/openssl";

    NSString * extFilePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"x509.ext"];

    NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];
 
    NSString * icecastServerSourcePassword = [self.appDelegate.localRadioAppSettings valueForKey:@"IcecastServerSourcePassword"];
    NSString * passphrase = [NSString stringWithFormat:@"pass:%@", icecastServerSourcePassword];
    
    NSString * caSerialFilePath = [applicationSupportDirectoryPath stringByAppendingString:@"CA.srl"];

    NSArray * openSSLTaskArgsArray = [NSArray arrayWithObjects:
            @"x509",
            @"-req",
            @"-in",
            icecastServerCertificateSigningRequestFilePath,
            @"-CA",
            caCertificateFilePath,
            @"-CAkey",
            caRSAKeyFilePath,
            @"-CAcreateserial",
            @"-CAserial",
            caSerialFilePath,
            @"-out",
            icecastServerCertificateFilePath,
            @"-days",
            @"1825",
            @"-sha256",
            @"-extfile",
            extFilePath,
            @"-extensions",
            @"server",
            @"-passin",
            passphrase,
            NULL];

    NSString * openSSLTaskArgsString = [openSSLTaskArgsArray componentsJoinedByString:@" "];
    
    NSLog(@"Launching openssl NSTask: \"%@\" \"%@\"", openSSLPath, openSSLTaskArgsString);
    
    NSTask * openSSLCATask = [[NSTask alloc] init];
    openSSLCATask.launchPath = openSSLPath;
    openSSLCATask.arguments = openSSLTaskArgsArray;

    [openSSLCATask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

    //IcecastController * weakSelf = self;
    __block BOOL taskDone = NO;
    
    [openSSLCATask setTerminationHandler:^(NSTask* task)
    {
        NSLog(@"LocalRadio IcecastController enter createCertificateAuthority openssl terminationHandler, PID=%d", task.processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"LocalRadio IcecastController createCertificateAuthority - openssl terminationStatus 0");
        }
        else
        {
            NSLog(@"LocalRadio IcecastController createCertificateAuthority - openssl terminationStatus %d", task.terminationStatus);
        }
        
        taskDone = YES;
    }];
    
    [openSSLCATask launch];

    while (taskDone == NO)
    {
        usleep(5000);
    }

}

// ============================================================================================
//
// ============================================================================================

- (void)createIcecastServerComboCertificate:(NSString *)icecastServerComboCertificateFilePath
        key:(NSString *)icecastServerKeyFilePath certificate:(NSString *)icecastServerCertificateFilePath
{
    // openssl x509 -req -sha256 -CA LocalRadioCA.pem -CAkey LocalRadioCA.key -days 730 -CAcreateserial -CAserial CA.srl -extfile x509.ext -extensions server -in icecast.csr -out icecast.pem

    NSLog(@"IcecastController - createIcecastServerComboCertificate:%@", icecastServerComboCertificateFilePath);

    NSError * removeCertificateFileError;
    [NSFileManager.defaultManager removeItemAtPath:icecastServerComboCertificateFilePath error:&removeCertificateFileError];

    NSError * keyFileError;
    NSString * keyString = [NSString stringWithContentsOfFile:icecastServerKeyFilePath encoding:NSUTF8StringEncoding error:&keyFileError];

    NSError * certificateFileError;
    NSString * certificateString = [NSString stringWithContentsOfFile:icecastServerCertificateFilePath encoding:NSUTF8StringEncoding error:&certificateFileError];

    NSString * comboString = [NSString stringWithFormat:@"%@%@", keyString, certificateString];
    
    NSError * comboFileError;
    [comboString writeToFile:icecastServerComboCertificateFilePath atomically:YES encoding:NSUTF8StringEncoding error:&comboFileError];
}

// ============================================================================================
//
// ============================================================================================

- (void)createIcecastServerCertificateWrapper:(NSString *)icecastServerCertificateWrapperFilePath
        key:(NSString *)icecastServerKeyFilePath certificate:(NSString *)icecastServerCertificateFilePath
        caCertificate:(NSString *)caCertificateFilePath certificateChain:(NSString *)serverCertificateChainFilePath
{
    // store LocalRadio Icecast server certificate in keychain
    // adapted from DDKeychain

    NSLog(@"IcecastController - createIcecastServerCertificateWrapper:%@", icecastServerCertificateWrapperFilePath);

    // compose a pem file with concatenated certificates of chain of trust

    NSError * serverCertificateError = NULL;
    NSString * serverCertificateString = [NSString stringWithContentsOfFile:icecastServerCertificateFilePath encoding:NSASCIIStringEncoding error:&serverCertificateError];

    NSError * caCertificateError = NULL;
    NSString * caCertificateString = [NSString stringWithContentsOfFile:caCertificateFilePath encoding:NSASCIIStringEncoding error:&caCertificateError];

    // combine certificates into a single pem file for p12
    NSString * certificateChainString = [NSString stringWithFormat:@"%@%@", serverCertificateString, caCertificateString];
    NSError * certificateChainError = NULL;
    [certificateChainString writeToFile:serverCertificateChainFilePath atomically:YES encoding:NSASCIIStringEncoding error:&certificateChainError];

    SecKeychainRef keychain = NULL;
    CFArrayRef outItems = NULL;

    NSError * removeCertificateWrapperFileError;
    [NSFileManager.defaultManager removeItemAtPath:icecastServerCertificateWrapperFilePath error:&removeCertificateWrapperFileError];

    // Adapted from DDKeychain -

    // Mac OS X has problems importing private keys, so we wrap everything in PKCS#12 format
    // You can create a p12 wrapper by running the following command in the terminal:
    // openssl pkcs12 -export -in certificate.crt -inkey private.pem
    //   -passout pass:password -out certificate.p12 -name "Open Source"

    NSString * icecastServerSourcePassword = [self.appDelegate.localRadioAppSettings valueForKey:@"IcecastServerSourcePassword"];
    NSString * passphrase = [NSString stringWithFormat:@"pass:%@", icecastServerSourcePassword];

    NSArray *certWrapperArgs = [NSArray arrayWithObjects:
            //@"pkcs12", @"-export", @"-export",
            @"pkcs12", @"-export",
            @"-in", serverCertificateChainFilePath,
            @"-inkey", icecastServerKeyFilePath,
            @"-passin", passphrase,
            @"-passout", passphrase,
            @"-out", icecastServerCertificateWrapperFilePath,
            @"-name", @"LocalRadioHTTPServer", nil];

    NSTask *genCertWrapperTask = [[NSTask alloc] init];
    
    [genCertWrapperTask setLaunchPath:@"/usr/bin/openssl"];
    [genCertWrapperTask setArguments:certWrapperArgs];
    [genCertWrapperTask launch];
    
    // Don't use waitUntilExit - I've had too many problems with it in the past
    do {
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    } while([genCertWrapperTask isRunning]);
    
    // import the identity into the keychain
    NSData *certData = [NSData dataWithContentsOfFile:icecastServerCertificateWrapperFilePath];
    
    SecKeyImportExportFlags importFlags = kSecKeyImportOnlyOne;
    
    SecItemImportExportKeyParameters importParameters;
    importParameters.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
    importParameters.flags = importFlags;
    importParameters.passphrase = (__bridge CFTypeRef _Nullable)(icecastServerSourcePassword);
    importParameters.accessRef = NULL;
    importParameters.keyUsage = NULL;   // all operations are allowed by default (CSSM_KEYUSE_ANY)
    importParameters.keyAttributes = NULL;  // defaults - permanent, CSSM_KEYATTR_SENSITIVE | CSSM_KEYATTR_EXTRACTABLE
    
    SecExternalFormat inputFormat = kSecFormatPKCS12;
    SecExternalItemType itemType = kSecItemTypeUnknown;

    SecKeychainCopyDefault(&keychain);
    
    OSStatus err = 0;
    
    err = SecItemImport((__bridge CFDataRef)certData, // CFDataRef importedData
            NULL,                       // CFStringRef fileNameOrExtension
            &inputFormat,               // SecExternalFormat *inputFormat
            &itemType,                  // SecExternalItemType *itemType
            0,                          // SecItemImportExportFlags flags (Unused)
            &importParameters,          // const SecKeyImportExportParameters *keyParams
            keychain,                   // SecKeychainRef importKeychain
            &outItems);                 // CFArrayRef *outItems
    
    NSLog(@"OSStatus: %i", err);
    
    NSLog(@"SecExternalFormat: %@", [DDKeychain_LocalRadio stringForSecExternalFormat:inputFormat]);
    NSLog(@"SecExternalItemType: %@", [DDKeychain_LocalRadio stringForSecExternalItemType:itemType]);
    
    NSLog(@"outItems: %@", (__bridge NSArray *)outItems);
    
    if(keychain)   CFRelease(keychain);
    if(outItems)   CFRelease(outItems);
}

// ============================================================================================
//
// ============================================================================================

- (NSString *)localHostString
{
    NSString * bonjourName = [[NSHost currentHost] name];
    
    NSArray * hostNames = [[NSHost currentHost] names];
    
    for (NSString * aHostName in hostNames)
    {
        NSRange localRange = [aHostName rangeOfString:@".local"];
        if (localRange.location == aHostName.length - 6)
        {
            bonjourName = aHostName;
            break;
        }
    }
    
    return bonjourName;
}


@end
