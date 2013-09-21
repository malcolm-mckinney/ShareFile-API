//
//  Sample.h
//  ShareFileSample
//
//  Created by Malcolm McKinney on 8/1/13.
//  Copyright (c) 2013 Malcolm McKinney. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Sample : NSObject <NSURLConnectionDelegate>


- (BOOL)authenticate: (NSString*)aSubdomain
             withTLD: (NSString*)aTLD
        withUserName: (NSString*)aUsername
        withPassword: (NSString*)aPassword;

- (void) folderList: (NSString*) path;

-(NSString*) urlEncodeUsingEncoding:(NSString*) unescapedString;

- (BOOL) fileUpload:         (NSString*) localPath
 optionalDictionary: (NSDictionary*) optionalParameters;

- (BOOL)fileSend:            (NSString*)     path
addressOfRecipient:  (NSString*)     emailRecipient
  subjectOfEmail:      (NSString*)     emailSubject
 extraParameters:     (NSDictionary*) optionalParameters;

- (BOOL) usersCreate:  (NSString*)     firstName
        withLastName:  (NSString*)     lastName
           withEmail:  (NSString*)     emailAddress
     withCompanyName:  (NSString*)     companyName
    userIsAnEmployee:  (BOOL)          isEmployee
     extraParameters:  (NSDictionary*) optionalParameters;

-(BOOL) groupCreate: (NSString*) groupName
    extraParameters: (NSDictionary*) optionalParameters;

-(BOOL) search:          (NSString*) query
extraParameters: (NSDictionary*) optionalParameters;

-(NSString*) appendOptionalParamsToURLString: (NSString*)     URLString
                          withOptionalParams: (NSDictionary*) optionalParams;

-(BOOL) uploadHelper: (NSString*) uploadURLString
            withPath:     (NSString*) localPath
           withError: (NSError**) error;

- (NSDictionary*) invokeShareFileOperation: (NSString*) requestURL
                                 withError: (NSError**) error;

- (BOOL)fileDownload: (NSString*) fileID
       withLocalPath: (NSString*) localPath;

@end
