/**
 * Copyright (c) 2013 Citrix Systems, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <unistd.h>
#include <CFNetwork/CFNetwork.h>

#define BUFFER_SIZE 4096

@interface Sample : NSObject <NSURLConnectionDelegate, NSStreamDelegate>

{
    //Total number of bytes downloaded and uploaded
    NSUInteger bytesDownloaded;
    NSUInteger bytesUploaded;
    
    //Used to block the main thread from finishing
    BOOL downloadFinished;
    BOOL uploadFinished;
    
    //Used in downloading files
    NSMutableData *responseData;
    NSURLResponse *lastResponse;
    
    //The file stream for uploading a file from disc
    NSInputStream *fileStream;
    
    //A check whether the user is downloading or uploading
    BOOL isDownloading;
   
    //A check to see which stage of the multipart POST user is in
    BOOL prefixWritten;
    BOOL bodyWritten;
    BOOL suffixWritten;
    
    //Holds the string containing prefix and suffix data in multipart POST
    NSData *prefix;
    NSData *suffix;
    
    //Used to stream data for uploads and downloads
    NSInputStream *inputStream;
    NSOutputStream *outputStream;

    //Fields that are useful for uploading and downloading
    NSUInteger fileSize;
    NSUInteger contentLength;
    NSUInteger bufferOffset;
    NSUInteger dataUploaded;
    
    //The buffer the output stream is writing to 
    void *buffer;

};

-(BOOL)authenticate: (NSString*) aSubdomain
            withTLD: (NSString*) aTLD
       withUserName: (NSString*) aUsername
       withPassword: (NSString*) aPassword;

-(void)folderList: (NSString*) path;

-(BOOL)fileDownload: (NSString*) fileID
      withLocalPath: (NSString*) localPath;


-(BOOL)fileUpload:         (NSString*)     localPath
       optionalDictionary: (NSDictionary*) optionalParameters;

-(BOOL)fileSend:            (NSString*)     path
       addressOfRecipient:  (NSString*)     emailRecipient
       subjectOfEmail:      (NSString*)     emailSubject
       extraParameters:     (NSDictionary*) optionalParameters;


-(BOOL)usersCreate:  (NSString*)     firstName
      withLastName:  (NSString*)     lastName
         withEmail:  (NSString*)     emailAddress
   withCompanyName:  (NSString*)     companyName
  userIsAnEmployee:  (BOOL)          isEmployee
   extraParameters:  (NSDictionary*) optionalParameters;

-(BOOL) groupCreate: (NSString*)     groupName
    extraParameters: (NSDictionary*) optionalParameters;

-(BOOL) search:          (NSString*)     query
        extraParameters: (NSDictionary*) optionalParameters;

-(NSString*) urlEncodeUsingEncoding:(NSString*) unescapedString;

-(NSString*) appendOptionalParamsToURLString: (NSString*)     URLString
                          withOptionalParams: (NSDictionary*) optionalParams;

-(BOOL) uploadHelper: (NSString*)   uploadURLString
            withPath: (NSString*)   localPath
           withError: (NSError**)   error;

-(NSDictionary*) invokeShareFileOperation: (NSString*) requestURL
                                withError: (NSError**) error;

@end


@implementation Sample

NSString *subdomain;
NSString *tld;
NSString *authid;

//
//  Authenticates a session for the use of ShareFile services.
//
//  A login to https://mycompany.sharefile.com would be programatically called as such:
//
//  [shareFile authenticate: @"mycompany"
//                  withTLD: @"shareFile"
//             withUserName: @"myUsername"
//             withPassword: @"myPassword"];
//
//  Returns true if authentification is successful.
//

- (BOOL)authenticate: (NSString*) aSubdomain
             withTLD: (NSString*) aTLD
        withUserName: (NSString*) aUsername
        withPassword: (NSString*) aPassword

{
    NSString *requestURL;
    NSDictionary *jsonResponse;
    NSError *error;
    
    subdomain = aSubdomain;
    tld = aTLD;
    error = nil;
    
    requestURL = [@"https://" stringByAppendingFormat:
                  @"%@.%@/rest/getAuthID.aspx?username=%@&fmt=json&password=%@",
                  subdomain,
                  tld,
                  [self urlEncodeUsingEncoding: aUsername],
                  [self urlEncodeUsingEncoding: aPassword]];
    
    jsonResponse = [self invokeShareFileOperation: requestURL withError: &error];
       
    if (error || [jsonResponse[@"error"]boolValue]) {
        
        if (jsonResponse) {
            
           NSLog(@"ErrorCode %@: %@",jsonResponse[@"errorCode"], jsonResponse [@"errorMessage"]);
            
        } else {
            
            NSLog(@"%ld : %@", (long)error.code, error.description);
        }
        return false;
    }
    
    authid = [jsonResponse objectForKey:@"value"];
    
    if (!authid) {
        
        NSLog(@"Could not obtain authentification id.");
        return false;
    }
    
    return true;
}

//
//  Prints out a folder list for the specified path or root if none is provided.
//

- (void)folderList: (NSString*) localPath

{
    NSString *requestURL;
    NSDictionary *jsonResponse;
    NSError *error;
    
    if (!authid) {
        
        NSLog(@"Must authenticate before printing folder list.");
        return;
    }
    
    error = nil;
    requestURL = [@"https://" stringByAppendingFormat:
                  @"%@.%@/rest/folder.aspx?path=%@&fmt=json&op=list&authid=%@",
                  subdomain,
                  tld,
                  [self urlEncodeUsingEncoding: localPath],
                  authid];
    
    jsonResponse = [self invokeShareFileOperation: requestURL withError: &error];
    
    if (error || [jsonResponse[@"error"]boolValue]) {
        
        if (jsonResponse) {
            
            NSLog(@"ErrorCode %@: %@",jsonResponse[@"errorCode"], jsonResponse [@"errorMessage"]);
            
        } else {
            
            NSLog(@"%ld : %@", (long)error.code, error.description);
        }
        return;
    }
    
    for (NSDictionary *dictionary in [jsonResponse objectForKey: @"value"]) {
        NSLog(@"%@ %@ %@ %@", [dictionary objectForKey:@"id"],
                              [dictionary objectForKey:@"filename"],
                              [dictionary objectForKey:@"creationdate"],
                              [dictionary objectForKey:@"type"]);
    }
}

//
//  Uploads a file to ShareFile. 
//
//  See api.sharefile.com for optional parameter names
//
//  Returns true if file upload is successful.
//

- (BOOL)fileUpload:         (NSString*)     localPath
        optionalDictionary: (NSDictionary*) optionalParameters

{
    NSString *filename;
    NSString *requestURL;
    NSDictionary *jsonResponse;
    NSError *error;
    NSString *uploadURLString;
    
    if (!authid) {
       
        NSLog(@"Must authenticate before uploading file.");
        return false;
    }

    error = nil;
    filename = [localPath lastPathComponent];
                
    requestURL = [@"https://" stringByAppendingFormat:
                  @"%@.%@/rest/file.aspx?authid=%@&fmt=json&op=upload&filename=%@",
                  subdomain,
                  tld,
                  authid,
                  [self urlEncodeUsingEncoding: filename]];
    
         
    requestURL = [self appendOptionalParamsToURLString: requestURL
                                    withOptionalParams: optionalParameters];
    
    jsonResponse = [self invokeShareFileOperation: requestURL withError: &error];
    
    if (error || [jsonResponse[@"error"]boolValue]) {
        
        if (jsonResponse) {
            
            NSLog(@"ErrorCode %@: %@",jsonResponse[@"errorCode"], jsonResponse [@"errorMessage"]);
            
        } else {
            
            NSLog(@"%ld : %@", (long)error.code, error.description);
        }
        return false;
    }
    
    uploadURLString = [jsonResponse objectForKey:@"value"];

    if (![self uploadHelper:uploadURLString withPath:localPath withError: &error]) {
        
        NSLog(@"%ldhi : %@", (long)error.code, error.description);
        return false;
    }
    
    return true;
}

//
//  Downloads a file to ShareFile.
//
//  See api.sharefile.com for optional parameter names
//
//  Returns true if file download is successful.
//

- (BOOL)fileDownload: (NSString*) fileID
        withLocalPath: (NSString*) localPath
{
    NSString *filename;
    NSString *requestURL;
    NSDictionary *jsonResponse;
    NSError *error;
    NSString *downloadURLString;
    NSURLConnection * connection = nil;
    
    if (!authid) {
        
        NSLog(@"Must authenticate before downloading file.");
        return false;
    }
    
    error = nil;
    filename = [localPath lastPathComponent];
    
    requestURL = [@"https://" stringByAppendingFormat:
                  @"%@.%@/rest/file.aspx?authid=%@&fmt=json&op=download&id=%@",
                  subdomain,
                  tld,
                  authid,
                  [self urlEncodeUsingEncoding: fileID]];
    
    jsonResponse = [self invokeShareFileOperation: requestURL withError: &error];
    
    if (error || [jsonResponse[@"error"]boolValue]) {
        
        if (jsonResponse) {
            
            NSLog(@"ErrorCode %@: %@",jsonResponse[@"errorCode"], jsonResponse [@"errorMessage"]);
            
        } else {
            
            NSLog(@"%ld : %@", (long)error.code, error.description);
        }
        return false;
    }

    downloadURLString = jsonResponse[@"value"];
    
    outputStream = [[NSOutputStream alloc] initToFileAtPath:localPath append:YES];
    [outputStream open];
    
    NSURL *url = [NSURL URLWithString: downloadURLString];
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:url
                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                              timeoutInterval:60];
    
    responseData = [[NSMutableData alloc] initWithLength:0];
    isDownloading = true;
    downloadFinished = false;
    connection = [[NSURLConnection alloc] initWithRequest:theRequest
                                          delegate:self
                                          startImmediately:YES];
    while(!downloadFinished) {
        
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
    downloadFinished = false;
    isDownloading = false;
    return true;
}

//
//  Sends a "Send a file" email.
//
//  See api.sharefile.com for optional parameter names
//
//  Returns true if email has been sent.
//

- (BOOL)fileSend:            (NSString*)     path
        addressOfRecipient:  (NSString*)     emailRecipient
        subjectOfEmail:      (NSString*)     emailSubject
        extraParameters:     (NSDictionary*) optionalParameters
{
    
    NSString *requestURL;
    NSDictionary *jsonResponse;
    NSError *error;
    
    if (!authid) {
       
        NSLog(@"Must authenticate before sending 'Send a File' email.");
        return false;
    }
    
    error = nil;
    requestURL = [@"https://" stringByAppendingFormat:
                  @"%@.%@/rest/file.aspx?authid=%@&fmt=json&op=send&path=%@&to=%@&subject=%@",
                  subdomain,
                  tld,
                  authid,
                  [self urlEncodeUsingEncoding: path],
                  [self urlEncodeUsingEncoding: emailRecipient],
                  [self urlEncodeUsingEncoding: emailSubject]];
    
    requestURL = [self appendOptionalParamsToURLString: requestURL
                                    withOptionalParams: optionalParameters];
    
    jsonResponse = [self invokeShareFileOperation: requestURL withError:  &error];
   
    if (error || [jsonResponse[@"error"]boolValue]) {
        
        if (jsonResponse) {
            
            NSLog(@"ErrorCode %@: %@",jsonResponse[@"errorCode"], jsonResponse [@"errorMessage"]);
            
        } else {
            
            NSLog(@"%ld : %@", (long)error.code, error.description);
        }
        return false;
    }
    
    return true;
}

//
//  Creates a client or employee user in ShareFile.
//
//  Set userIsAnEmployee: isEmployee to true in order to create an employee, or false to create a client
//
//  See api.sharefile.com for optional parameter names
//
//

-(BOOL) usersCreate:     (NSString*) firstName
        withLastName:    (NSString*) lastName
        withEmail:       (NSString*) emailAddress
        withCompanyName: (NSString*) companyName
        userIsAnEmployee:(BOOL)      isEmployee
        extraParameters: (NSDictionary*) optionalParameters

{
    NSString *requestURL;
    NSDictionary *jsonResponse;
    NSError *error;
    
    if (!authid) {
        NSLog(@"Must authenticate before creating users.");
        return false;
    }
    
    error = nil;
    
    requestURL = [@"https://" stringByAppendingFormat:
                  @"%@.%@/rest/users.aspx?authid=%@&fmt=json&op=create&"
                  "firstname=%@&lastname=%@&email=%@&isemployee=%@&company=%@",
                   subdomain,
                   tld,
                   authid,
                   [self urlEncodeUsingEncoding: firstName],
                   [self urlEncodeUsingEncoding: lastName],
                   [self urlEncodeUsingEncoding: emailAddress],
                   isEmployee? @"true": @"false",
                   [self urlEncodeUsingEncoding: companyName]];
    
    requestURL = [self appendOptionalParamsToURLString: requestURL
                                    withOptionalParams: optionalParameters];

    jsonResponse = [self invokeShareFileOperation: requestURL withError:  &error];
    NSLog(@"%@", jsonResponse);
    
    if (error || [jsonResponse[@"error"]boolValue] ) {
        
        if (jsonResponse) {
            
            NSLog(@"ErrorCode %@: %@",jsonResponse[@"errorCode"], jsonResponse [@"errorMessage"]);
            
        } else {
            
            NSLog(@"%ld : %@", (long)error.code, error.description);
        }
        return false;
    }
   
    return true;
}

//
//  Creates a distribution group in ShareFile.
//
//  See api.sharefile.com for optional parameter names
//

-(BOOL) groupCreate: (NSString*) groupName
    extraParameters: (NSDictionary*) optionalParameters
{
    NSString *requestURL;
    NSDictionary *jsonResponse;
    NSError *error;
    
    if (!authid) {
        NSLog(@"Must authenticate before creating distribution group.");
        return false;
    }
    
    error = nil;
    requestURL =  [@"https://" stringByAppendingFormat:
                   @"%@.%@/rest/group.aspx?authid=%@&fmt=json&op=create&name=%@",
                   subdomain,
                   tld,
                   authid,
                   [self urlEncodeUsingEncoding: groupName]];
    
    requestURL = [self appendOptionalParamsToURLString: requestURL
                                    withOptionalParams: optionalParameters];
   
    jsonResponse = [self invokeShareFileOperation: requestURL withError:  &error];
    
    if (error || [jsonResponse[@"error"]boolValue]) {
        
        if (jsonResponse) {
            
            NSLog(@"ErrorCode %@: %@",jsonResponse[@"errorCode"], jsonResponse [@"errorMessage"]);
            
        } else {
            
            NSLog(@"%ld : %@", (long)error.code, error.description);
        }
        return false;
    }
    
    
    return true;
}

//
//  Search for items in ShareFile.
//
//  See api.sharefile.com for optional parameter names
//


-(BOOL) search:          (NSString*) query
        extraParameters: (NSDictionary*) optionalParameters
{
    
    NSString *requestURL;
    NSDictionary *jsonResponse;
    NSError *error;
    NSString *path;
    
    if (!authid) {
        NSLog(@"Must authenticate before searcching for items.");
        return false;
    }
    
    error = nil;
    requestURL = [@"https://" stringByAppendingFormat:
                  @"%@.%@/rest/search.aspx?authid=%@&fmt=json&op=search&query=%@",
                  subdomain,
                  tld,
                  authid,
                  [self urlEncodeUsingEncoding: query]];
    
    requestURL = [self appendOptionalParamsToURLString: requestURL
                                    withOptionalParams: optionalParameters];
    
    jsonResponse = [self invokeShareFileOperation: requestURL withError: &error];
    
    if (error || [jsonResponse[@"error"]boolValue]) {
        
        if (jsonResponse) {
            
            NSLog(@"ErrorCode %@: %@",jsonResponse[@"errorCode"], jsonResponse [@"errorMessage"]);
            
        } else {
            
            NSLog(@"%ld : %@", (long)error.code, error.description);
        }
        return false;
    }


    for (NSDictionary *item in jsonResponse[@"value"]) {
        
        path = [item[@"parentid"] isEqualToString: @"box"] ? @"/File Box" : item[@"parentsemanticpath"];
        NSLog(@"%@/%@ %@ %@", path, item[@"filename"], item[@"creationdate"], item[@"type"]);
    }
    
    return true;
}

                                                    /* Helper Functions */


//  Helper function to get JSON data from URL

- (NSDictionary*) invokeShareFileOperation: (NSString*) requestURL
                                 withError:  (NSError**) error
{
    NSURLRequest *request;
    NSURLResponse *urlResponse;
    NSData *data;
    
    request  = [NSURLRequest requestWithURL:[NSURL URLWithString: requestURL]];
    
    if (!request) {
        NSLog(@"%@",[NSString stringWithFormat:@"Could not create URL request."]);
        return nil;
    }
    
    data = [NSURLConnection sendSynchronousRequest: request
                                 returningResponse: &urlResponse
                                            error : error];
    
    if (!data) {
        
        NSLog(@"%@",[NSString stringWithFormat:@"Data request failed."]);
        return nil;
    }
    
    return [NSJSONSerialization JSONObjectWithData: data
                                          options : kNilOptions
                                          error   : error];
}

//  Helper function to upload files via ShareFile


-(BOOL) uploadHelper: (NSString*) uploadURLString
        withPath:     (NSString*) localPath
        withError: (NSError**) error

{

    NSURL *uploadURL;
    NSString *filename;
    NSMutableURLRequest *request;
    NSString *boundaryStr;
    NSString *prefixStr;
    NSString *suffixStr;
    
    bytesUploaded = 0;
    dataUploaded = 0;
    buffer = nil;
    
    uploadURL = [NSURL URLWithString:uploadURLString];
    
    if (!uploadURL)
    {
        NSLog(@"%@",[NSString stringWithFormat:@"Could not create URL from string: %@", uploadURLString]);
        return false;
    }
 
    request = [NSMutableURLRequest requestWithURL:uploadURL];
    boundaryStr = @"123123123432123";
    
    if (!request) {
        
        NSLog(@"%@",[NSString stringWithFormat:@"Could not create URL request from string: %@", uploadURLString]);
        return false;
    }
   
    filename = [localPath lastPathComponent];
    
    prefixStr = [NSString stringWithFormat:
                 @"Content-Disposition: form-data; name=""{File1}""; filename=""{%@}""" 
                 "\r\nContent-Type: application/octet-stream\r\n\r\n",filename];
      
    suffixStr = [NSString stringWithFormat: @"\r\n--%@--\r\n", boundaryStr];
    
    prefix = [prefixStr dataUsingEncoding:NSUTF8StringEncoding];
    suffix = [suffixStr dataUsingEncoding:NSUTF8StringEncoding];
    
    fileStream = [[NSInputStream alloc]initWithFileAtPath: localPath];
    
    if(!fileStream) {
        NSLog(@"%@",[NSString stringWithFormat:@"Could not open stream: %@", uploadURLString]);
        return false;
    }
    
    [fileStream open];
    
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreateBoundPair(NULL, &readStream, &writeStream, BUFFER_SIZE);
    
    inputStream = (__bridge_transfer NSInputStream *)readStream;
    outputStream = (__bridge_transfer NSOutputStream *)writeStream;
 
    [outputStream setDelegate:self];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream open];
    
    fileSize = (unsigned long long)[[[NSFileManager defaultManager]attributesOfItemAtPath: localPath error: nil][@"NSFileSize"]unsignedLongValue];
    contentLength = fileSize + [prefix length]+[suffix length];
    
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)contentLength]  forHTTPHeaderField: @"Content-Length"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundaryStr] forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBodyStream:inputStream];
    [request setHTTPMethod:@"POST"];
    [request setTimeoutInterval: 230];
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    while(!uploadFinished) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
    uploadFinished = false;
    connection = nil;
    return true;
}

// Helper functiion to get encoding from URL

-(NSString*) urlEncodeUsingEncoding:(NSString*) unescapedString
{
  return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
         NULL,
         (__bridge CFStringRef) unescapedString,
         NULL,
         CFSTR("!*'();:@&=+$,/?%#[]"),
         kCFStringEncodingUTF8));
}


//  Helper function to add dictionary parameters to URL string

-(NSString*) appendOptionalParamsToURLString:  (NSString*) URLString
                       withOptionalParams: (NSDictionary*) optionalParams

{
    if (optionalParams == nil) {
        
        return URLString;
    }
    
    NSMutableArray *sections = [NSMutableArray new];
    for (id key in optionalParams) {
        
        id value = [optionalParams objectForKey: key];
        NSString *part = [NSString stringWithFormat: @"%@=%@",
                          [self urlEncodeUsingEncoding: key],
                          [self urlEncodeUsingEncoding: value]];
        [sections addObject: part];
    }
    
    return [URLString stringByAppendingFormat: @"/%@",[sections componentsJoinedByString: @"&"]];
}

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    
    NSHTTPURLResponse * httpResponse;
    httpResponse = (NSHTTPURLResponse *) response;
    lastResponse = response;
    
    // Check for bad connection
    if ([response expectedContentLength] < 0)
    {
        NSLog(@"Invalid URL");
        return;
    }
    
    responseData = [[NSMutableData alloc] init];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSUInteger bytesToWrite; 
    NSUInteger bytesWritten;
    
    if (isDownloading) {
        
        bytesToWrite = [data length];
        bytesWritten = 0;
        
        do  {
            
            bytesWritten = [outputStream write:[data bytes] maxLength:bytesToWrite];
            
            if (bytesToWrite == -1) {
                
                break;
            }
            
            bytesToWrite -= bytesWritten;
            
        }   while (bytesToWrite > 0);
            
        if (bytesToWrite) {
            
            NSLog(@"stream error: %@", [outputStream streamError]);
        }
        
        if (lastResponse) {
            
            float expectedLength = [lastResponse expectedContentLength];
            bytesDownloaded += bytesWritten;
            float percent = bytesDownloaded * 100 / expectedLength;
            NSLog(@"File is %@%% completed.", [NSString stringWithFormat:@"%.02f", percent]);
        }
    }
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {

    NSLog(@"%ld : %@", (long)error.code, error.description);    
}

- (NSCachedURLResponse *) connection:(NSURLConnection *)connection willCacheResponse: (NSCachedURLResponse *)cachedResponse {
    return nil;
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
    
    if (isDownloading) {
        
        NSLog(@"Succeeded! Received %ld bytes of data", (unsigned long)bytesDownloaded);
        
        downloadFinished = true;
        bytesDownloaded = 0;
    
    } else {
        
        uploadFinished = true;
    }
    
}

//Event handler for uploading mulipart files

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
   
    NSInteger bytesRead = 0;
    NSInteger bytesWritten = 0;
    const void* buff = NULL;
    
    switch (eventCode) {
        
        case NSStreamEventOpenCompleted:
           
            break;
   
        case NSStreamEventHasBytesAvailable:
            
            break;
            
        case NSStreamEventHasSpaceAvailable:
        
            bufferOffset = (bufferOffset == BUFFER_SIZE) ? 0 : bufferOffset;
            
            //Writes the prefix to the buffer
            if (!prefixWritten) {
                
                if (bufferOffset == 0) {
                    
                    buff = [prefix bytes] + bytesUploaded;
                }
                
                bytesWritten = [outputStream write:&buff[bufferOffset] maxLength:MIN([prefix length], (BUFFER_SIZE - bufferOffset))];
                bytesUploaded += bytesWritten;
                bufferOffset += bytesWritten;
                
                if (bytesUploaded == [prefix length]) {
                    
                    prefixWritten = true;
                    bufferOffset = 0;
                    bytesUploaded = 0;
                    buffer = malloc(BUFFER_SIZE);
                }
            }
 
            //Writes the body to the buffer
            if (!bodyWritten) {
                
                bytesRead = [fileStream read:&buffer[bufferOffset] maxLength:BUFFER_SIZE - bufferOffset];

                if (bytesRead == -1) {
                   
                    NSLog(@"File stream error occured. Closing Stream.");
                    
                    if (buffer) {
                        
                        free(buffer);
                        buffer = nil;
                    }
                    
                    outputStream.delegate = nil;
                    [outputStream close];
                    uploadFinished = true;
                }
            
                if (bytesRead > 0) {
                    
                    bytesWritten  = [outputStream write:&buffer[bufferOffset] maxLength: bytesRead];
                    bufferOffset += bytesWritten;
                    bytesUploaded += bytesWritten;
                    
                    unsigned int percent = (unsigned int)bytesUploaded * 100 / fileSize;
                    NSLog(@"File is %d%% completed.", percent);
                    
                    if (percent == 100) {
                        
                        bytesUploaded = 0;
                        bufferOffset = 0;
                        [fileStream close];
                        free(buffer);
                        buffer = nil;
                        bodyWritten = true;
                    }
                }
                
            } else {
 
                //Writes the suffix to the buffer
                if (!suffixWritten) {
                    
                    if(bufferOffset == 0) {
                        
                        buff = [suffix bytes] + bytesUploaded;
                        bufferOffset = 0;
                    }
                    
                    bytesWritten += [outputStream write:&buff[bufferOffset] maxLength:MIN([suffix length], (BUFFER_SIZE - bufferOffset))];
                    bufferOffset += bytesWritten;
                    bytesUploaded += bytesWritten;
                    
                    if([suffix length] == bytesUploaded) {
                    
                        [inputStream open];
                        suffixWritten = true;
                        outputStream.delegate = nil;
                        [outputStream close];
                    }
                }
            }
            
            break;
   
        default:
            
            NSLog(@"Unhandled stream event (%ld)", eventCode);
            break;
    }
}

//  Silences an error

- (NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request {
  
    return inputStream;
}

//  Main method

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        
        NSMutableDictionary *myDictionary;
        
        Sample *shareFileSample = [[Sample alloc] init];
        [shareFileSample authenticate: (@"labs")
                     withTLD: (@"sharefile.com")
                withUserName: (@"malcolm.mckinney@citrix.com")
                withPassword: (@"Luigifan025")];
        
        //[shareFileSample search:@"myDocument.pdf" extraParameters:nil];
        /*
        myDictionary = [[NSMutableDictionary alloc]init];
  
        myDictionary[@"password"] = @"aPassword";
        myDictionary[@"notify"] = @"true";
        myDictionary[@"canviewmysettings"] = @"false";
        */
   
        [shareFileSample usersCreate: @"Jane"
                        withLastName: @"Smith"
                           withEmail: @"jayne@email.com"
                     withCompanyName: @"Company Name"
                    userIsAnEmployee: true
                     extraParameters: myDictionary];
        
        //[shareFileSample groupCreate:@"shareFile group" extraParameters:nil];
    }
    
    return 0;
}

@end

