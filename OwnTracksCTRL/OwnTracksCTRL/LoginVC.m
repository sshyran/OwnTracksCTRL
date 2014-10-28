//
//  LoginViewController.m
//  OwnTracksCTRL
//
//  Created by Christoph Krey on 24.10.14.
//  Copyright (c) 2014 OwnTracks. All rights reserved.
//

#import "LoginVC.h"
#import "AppDelegate.h"

@interface LoginVC ()
@property (weak, nonatomic) IBOutlet UITextField *UIuser;
@property (weak, nonatomic) IBOutlet UITextField *UIpassword;
@property (weak, nonatomic) IBOutlet UIButton *UILookup;

@property (strong, nonatomic) NSURLConnection *urlConnection;
@property (strong, nonatomic) NSMutableData *receivedData;

@property (nonatomic) BOOL firststart;

@end

@implementation LoginVC

- (void)loadView {
    [super loadView];
    self.firststart = true;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updated];
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate addObserver:self forKeyPath:@"token"
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self updateValues];
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate removeObserver:self forKeyPath:@"token"
                        context:nil];
    [appDelegate saveContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"token"]) {
        if ([object valueForKey:keyPath]) {
            if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                if (self.firststart) {
                    self.firststart = false;
                    [self lookup:nil];
                }
            }
        }
    }
}

- (void)updateValues {
    AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    if (self.UIuser) delegate.broker.user = self.UIuser.text;
    if (self.UIpassword) delegate.broker.passwd = self.UIpassword.text;
}

- (void)updated {
    AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    self.UIuser.text = delegate.broker.user;
    self.UIpassword.text = delegate.broker.passwd;
}

- (IBAction)touchedOutsideText:(UITapGestureRecognizer *)sender {
    [self updateValues];
    [self.UIuser resignFirstResponder];
    [self.UIpassword resignFirstResponder];
}

- (IBAction)changedUser:(UITextField *)sender {
    AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate trash];
}

- (IBAction)lookup:(UIButton *)sender {
    [self updateValues];
    AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    NSString *tokenPost = @"";
    if (delegate.token && delegate.token.length > 0) {
        tokenPost = [NSString stringWithFormat:@"&token=%@", delegate.token];
    }
    
    NSString *post = [NSString stringWithFormat:@"username=%@&password=%@%@",
                      delegate.broker.user,
                      delegate.broker.passwd,
                      tokenPost];
    
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%ld",(unsigned long)[postData length]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://demo.owntracks.de/ext/conf"]]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    self.receivedData = [[NSMutableData alloc] init];
    self.urlConnection = [[NSURLConnection alloc]initWithRequest:request delegate:self];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = true;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"NSURLResponse %@", response);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = false;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = false;
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Loading failed"
                                                        message:[error description]
                                                       delegate:nil
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"OK", nil];
    [alertView show];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = false;
    NSDictionary *dictionary = nil;
    if (self.receivedData.length) {
        NSError *error;
        dictionary = [NSJSONSerialization JSONObjectWithData:self.receivedData options:0 error:&error];
    }
    if (dictionary && [dictionary[@"_type"] isEqualToString:@"configuration"]) {
        NSLog(@"configuration %@", dictionary);
        AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        
        delegate.broker.host = [self stringFromJSON:dictionary key:@"host"];
        delegate.broker.port = [self numberFromJSON:dictionary key:@"port"];
        delegate.broker.auth = [self numberFromJSON:dictionary key:@"auth"];
        delegate.broker.tls = [self numberFromJSON:dictionary key:@"tls"];
        delegate.broker.user = [self stringFromJSON:dictionary key:@"username"];
        delegate.broker.passwd = [self stringFromJSON:dictionary key:@"password"];
        delegate.broker.trackurl = [self stringFromJSON:dictionary key:@"trackurl"];
        delegate.broker.certurl = [self stringFromJSON:dictionary key:@"certurl"];
        
        NSString *base = @"";
        for (NSString *topic in [self arrayFromJSON:dictionary key:@"topicList"]) {
            if (base.length) {
                base = [base stringByAppendingString:@" "];
            }
            base = [base stringByAppendingString:topic];
        }
        delegate.broker.base = base;
        
        delegate.broker.clientid = [self stringFromJSON:dictionary key:@"clientid"];
        [self updated];
        [self performSegueWithIdentifier:@"Login" sender:nil];
    } else {
        NSString *message = [AppDelegate dataToString:self.receivedData];
        if (dictionary) {
            if ([dictionary[@"message"] isKindOfClass:[NSString class]]) {
                message = dictionary[@"message"];
            }
        }
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Settings invalid"
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"OK", nil];
        [alertView show];
    }
}

- (IBAction)direct:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self performSegueWithIdentifier:@"Login" sender:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate connect];
}

- (NSString *)stringFromJSON:(NSDictionary *)dictionary key:(NSString *)key {
    NSString *string = nil;
    
    id object = [dictionary objectForKey:key];
    if (object) {
        if ([object isKindOfClass:[NSString class]]) {
            string = (NSString *)object;
        }
    }
    return string;
}

- (NSNumber *)numberFromJSON:(NSDictionary *)dictionary key:(NSString *)key {
    NSNumber *number = nil;
    
    id object = [dictionary objectForKey:key];
    if (object) {
        if ([object isKindOfClass:[NSNumber class]]) {
            number = (NSNumber *)object;
        }
    }
    return number;
}

- (NSArray *)arrayFromJSON:(NSDictionary *)dictionary key:(NSString *)key {
    NSArray *array = nil;
    
    id object = [dictionary objectForKey:key];
    if (object) {
        if ([object isKindOfClass:[NSArray class]]) {
            array = (NSArray *)object;
        }
    }
    return array;
}

@end
