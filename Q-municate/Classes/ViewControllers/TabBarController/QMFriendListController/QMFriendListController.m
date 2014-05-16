//
//  QMFriendListController.m
//  Q-municate
//
//  Created by Igor Alefirenko on 24/02/2014.
//  Copyright (c) 2014 Quickblox. All rights reserved.
//

#import "QMFriendListController.h"
#import "QMFriendsDetailsController.h"
#import "QMFriendListCell.h"
#import "QMContactList.h"
#import "QMFriendsListDataSource.h"

#define kSearchBarHeight            44.0f

#define kNoResultsViewTag           1101
#define kSearchGlobalButtonTag      1102


@interface QMFriendListController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) UISearchBar *searchBar;
@property (strong, nonatomic) UIView *searchResultsView;

@property (nonatomic, strong) QMFriendsListDataSource *dataSource;

@property (assign, nonatomic) BOOL searchBarIsShowed;
@property (assign, nonatomic) BOOL searchIsActive;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *viewHeight;

@end

@implementation QMFriendListController



- (void)viewDidLoad
{
    [super viewDidLoad];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    self.dataSource = [QMFriendsListDataSource new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fillTableView) name:kFriendsLoadedNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadFriendsList];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    if (self.searchBar != nil) {
        [self removeSearchBarAnimated:NO];
        self.tableView.tableFooterView = nil;
    }
}

- (void)reloadFriendsList
{
    self.tableView.tableFooterView = nil;
    [self updateDataSource];
}


#pragma mark - Footer

- (void)createNoResultsFooterViewWithButton:(BOOL)button
{
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 80)];
    if (button) {
        [self createNoResultsLabelWithGlobalSearchButtonForFooterView:footerView];
    } else {
        [self createAddMoreFriendsLabelForFooterView:footerView];
    }
    self.tableView.tableFooterView = footerView;
}

- (void)createAddMoreFriendsLabelForFooterView:(UIView *)footerView
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 300, 44)];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = kSearchingFriendsString;
    label.numberOfLines = 0;
    
    [footerView addSubview:label];
}

- (void)createNoResultsLabelWithGlobalSearchButtonForFooterView:(UIView *)footerView
{
    UILabel *noResultsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 22)];
    noResultsLabel.textAlignment = NSTextAlignmentCenter;
    noResultsLabel.text = kMoreResultString;
    noResultsLabel.numberOfLines = 0;
    
    [footerView addSubview:noResultsLabel];
    
     UIImage *buttonImage = [UIImage imageNamed:@"globalsearch-btn"];
    UIButton *globalSearchButton = [[UIButton alloc] initWithFrame:CGRectMake(160 - buttonImage.size.width/2 , 30, buttonImage.size.width, buttonImage.size.height)];
    [globalSearchButton setImage:buttonImage forState:UIControlStateNormal];
    [globalSearchButton addTarget:self action:@selector(searchGlobal:) forControlEvents:UIControlEventTouchUpInside];
    globalSearchButton.tag = kSearchGlobalButtonTag;
    
    [footerView addSubview:globalSearchButton];
}

- (void)removeFooterView
{
    self.tableView.tableFooterView = nil;
}


#pragma mark - Actions

- (IBAction)addToFriends:(id)sender
{
    UIButton *button = (UIButton *)sender;
    button.hidden = YES;
    NSInteger userIndex = button.tag;
    QBUUser *user = [self.dataSource.otherUsersArray objectAtIndex:userIndex];
    
    QMFriendListCell *cell = (QMFriendListCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:button.tag inSection:1]];
    [cell.indicatorView startAnimating];
    [[QMContactList shared] addUserToFriendList:user completion:^(BOOL success) {
        // reload friends
        [self reloadFriendsList];
    }];
}

- (void)searchGlobal:(id)sender
{
    NSString *searchText = self.searchBar.text;
    if ([searchText isEqualToString:kEmptyString]) {
        return;
    }
    [[QMContactList shared] retrieveUsersWithFullName:searchText completion:^(BOOL success) {
        if (success) {
            [self.dataSource updateOtherUsersArray:^(BOOL isEmpty) {
                self.tableView.tableFooterView = nil;
                [self.tableView reloadData];
            }];
        } else {
            UIButton *globalSearchButton = (UIButton *)[self.tableView.tableFooterView viewWithTag:kSearchGlobalButtonTag];
            globalSearchButton.hidden = YES;
            [self.tableView reloadData];
        }
    }];
}

- (IBAction)searchUsers:(id)sender
{
    if (_searchBarIsShowed) {
        [self removeSearchBarAnimated:YES];
    } else {
        [self createSearchBar];
    }
    _searchBarIsShowed = !_searchBarIsShowed;
}


#pragma mark - SearchBar

- (void)createSearchBar
{
    if (self.searchBar != nil) {
        return;
    }
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 20, 320, 44)];
    self.searchBar.delegate = self;
	self.searchBar.placeholder = kSearchFriendPlaceholdeString;
    
    self.viewHeight.constant += kSearchBarHeight;

    [self.navigationController.view insertSubview:self.searchBar atIndex:1];
    [UIView animateWithDuration:0.3 animations:^{
        self.tableView.transform = CGAffineTransformMakeTranslation(0, kSearchBarHeight);
        self.searchBar.transform = CGAffineTransformMakeTranslation(0, kSearchBarHeight);
        [self.view layoutIfNeeded];
    }];
}

- (void)removeSearchBarAnimated:(BOOL)animated
{
    if (self.searchBar == nil) {
        return;
    }
    self.searchIsActive = NO;
    [self.dataSource emptyOtherUsersArray];
    [self reloadFriendsList];
    [self.searchBar resignFirstResponder];
    [self.tableView reloadData];
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            self.tableView.transform = CGAffineTransformIdentity;
            self.searchBar.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            if (finished) {
                self.searchBar = nil;
                self.viewHeight.constant -= kSearchBarHeight;
                [self.view layoutIfNeeded];
            }
        }];
        return;
    }
    self.tableView.transform = CGAffineTransformIdentity;
    self.searchBar.transform = CGAffineTransformIdentity;
    self.searchBar = nil;
    self.viewHeight.constant -= kSearchBarHeight;
    [self.view layoutIfNeeded];
}


#pragma mark - UISearchBarDelegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    return YES;
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:NO animated:YES];
    return YES;
}

// search bar find text
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self createNoResultsFooterViewWithButton:YES];
    [self.dataSource emptyOtherUsersArray];
    self.searchIsActive = YES;

    if ([searchText isEqualToString:kEmptyString]) {
        self.searchIsActive = NO;
        [self reloadFriendsList];
        return;
    }
    [self.dataSource updateFriendsArrayForSearchPhrase:searchText];
    [self.tableView reloadData];
}

#pragma mark - Notifications

- (void)fillTableView
{
    [[NSNotificationCenter defaultCenter] removeObserver:kFriendsLoadedNotification];
    [self updateDataSource];
}

- (void)updateDataSource
{
    [self.dataSource updateFriendsArray:^(BOOL isEmpty) {
        if (isEmpty) {
            [self createNoResultsFooterViewWithButton:NO];
        } else {
			[self.tableView setTableFooterView:[[UIView alloc] init]];
		}
        [self.tableView reloadData];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return [self.dataSource.friendsArray count];
        case 1:
            return [self.dataSource.otherUsersArray count];
            
        default:
            break;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    QMFriendListCell *cell = [tableView dequeueReusableCellWithIdentifier:kFriendsListCellIdentifier];
    
    QBUUser *user = nil;
    if (indexPath.section == 0) {
        user = self.dataSource.friendsArray[indexPath.row];
    } else {
        user = self.dataSource.otherUsersArray[indexPath.row];
    }
    [cell configureCellWithParams:user searchText:self.searchBar.text indexPath:indexPath];
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (!_searchIsActive) {
        return kEmptyString;
    }
    if (section == 0) {
        if ([self.dataSource.friendsArray count] == 0) {
            return kEmptyString;
        }
        return kTableHeaderFriendsString;
    }
    if ([self.dataSource.otherUsersArray count] == 0) {
        return kEmptyString;
    }
    return kTableHeaderAllUsersString;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    QBUUser *currentUser;
    if (!indexPath.section) {
        currentUser = self.dataSource.friendsArray[indexPath.row];
        if (self.searchBar != nil) {
            [self removeSearchBarAnimated:NO];
        }
        _searchBarIsShowed = !_searchBarIsShowed;
        [self performSegueWithIdentifier:kDetailsSegueIdentifier sender:currentUser];
	}
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    ((QMFriendsDetailsController *)segue.destinationViewController).currentFriend = sender;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60.0f;
}

@end