import MixinStorage "blob-storage/Mixin";
import Time "mo:core/Time";
import Array "mo:core/Array";
import Nat "mo:core/Nat";
import Principal "mo:core/Principal";
import Map "mo:core/Map";
import List "mo:core/List";
import Storage "blob-storage/Storage";

import AccessControl "authorization/access-control";
import MixinAuthorization "authorization/MixinAuthorization";
import Runtime "mo:core/Runtime";


actor {
  type PortfolioItem = {
    title : Text;
    category : Text;
    media : Storage.ExternalBlob;
    mediaType : Text;
    createdAt : Int;
    description : Text;
  };

  type UserProfile = {
    name : Text;
    email : Text;
  };

  type ReorderPortfolioItem = {
    originalIndex : Nat;
    newIndex : Nat;
  };

  // Mutable variables for persistent state
  var portfolioItems = List.empty<PortfolioItem>();

  // Let-binding for the access control state (not persistent)
  let accessControlState = AccessControl.initState();

  // Helper functions for portfolio item operations (admin only)
  func addPortfolioItemInternal(title : Text, category : Text, media : Storage.ExternalBlob, mediaType : Text, description : Text) {
    let item : PortfolioItem = {
      title;
      category;
      media;
      mediaType;
      createdAt = Time.now();
      description;
    };
    portfolioItems.add(item);
  };

  // Helper functions for portfolio item deletion (admin only)
  func deletePortfolioItemInternal(index : Nat) {
    if (index >= portfolioItems.size()) {
      Runtime.trap("Index out of bounds");
    };
    let newArray = Array.tabulate(portfolioItems.size() - 1, func(i) { if (i < index) { portfolioItems.at(i) } else { portfolioItems.at(i + 1) } });
    portfolioItems := List.fromArray(newArray);
  };

  // Helper function for reordering portfolio items (admin only)
  func reorderPortfolioItemsInternal(moves : [ReorderPortfolioItem]) {
    var arr = portfolioItems.toArray();
    for (move in moves.values()) {
      if (move.originalIndex >= arr.size() or move.newIndex >= arr.size()) {
        Runtime.trap("Index out of bounds");
      };
      let item = arr[move.originalIndex];
      // Remove from original position
      arr := Array.tabulate(
        arr.size() - 1,
        func(i) {
          if (i < move.originalIndex) { arr[i] } else { arr[i + 1] };
        },
      );
      // Insert at new position
      arr := Array.tabulate(
        arr.size() + 1,
        func(i) {
          if (i < move.newIndex) { arr[i] } else if (i == move.newIndex) { item } else { arr[i - 1] };
        },
      );
    };
    portfolioItems := List.fromArray(arr);
  };

  func invertOrderPortfolioItemInternal() {
    portfolioItems := List.fromArray(portfolioItems.toArray().reverse());
  };

  // Helper function for updating portfolio items (admin only)
  func updatePortfolioItemInternal(index : Nat, title : ?Text, category : ?Text, media : ?Storage.ExternalBlob, mediaType : ?Text, description : ?Text) {
    if (index >= portfolioItems.size()) {
      Runtime.trap("Index out of bounds");
    };
    let item = portfolioItems.at(index);
    let updatedItem : PortfolioItem = {
      title = switch (title) {
        case (null) { item.title };
        case (?newTitle) { newTitle };
      };
      category = switch (category) {
        case (null) { item.category };
        case (?newCategory) { newCategory };
      };
      media = switch (media) {
        case (null) { item.media };
        case (?newMedia) { newMedia };
      };
      mediaType = switch (mediaType) {
        case (null) { item.mediaType };
        case (?newMediaType) { newMediaType };
      };
      createdAt = item.createdAt;
      description = switch (description) {
        case (null) { item.description };
        case (?newDescription) { newDescription };
      };
    };
    let newArray = Array.tabulate(
      portfolioItems.size(),
      func(i) {
        if (i == index) { updatedItem } else { portfolioItems.at(i) };
      },
    );
    portfolioItems := List.fromArray(newArray);
  };

  // Helper function for moving portfolio items to the end (admin only)
  func movePortfolioItemToEndInternal(index : Nat) {
    if (index >= portfolioItems.size()) {
      Runtime.trap("Index out of bounds");
    };
    let item = portfolioItems.at(index);
    let newArray = Array.tabulate(
      portfolioItems.size(),
      func(i) {
        if (i < index) { portfolioItems.at(i) } else if (i < portfolioItems.size() - 1) { portfolioItems.at(i + 1) } else { item };
      },
    );
    portfolioItems := List.fromArray(newArray);
  };

  let userProfiles = Map.empty<Principal, UserProfile>();
  include MixinStorage();
  include MixinAuthorization(accessControlState);

  // Claim admin access - only the first caller becomes admin (one-time operation)
  public shared ({ caller }) func claimAdminAccess() : async () {
    if (caller.isAnonymous()) {
      Runtime.trap("Anonymous callers cannot claim admin access");
    };
    if (accessControlState.adminAssigned) {
      Runtime.trap("Admin has already been claimed");
    };
    accessControlState.userRoles.add(caller, #admin);
    accessControlState.adminAssigned := true;
  };

  // Public operation - no auth required
  public query func getPortfolioItems() : async [PortfolioItem] {
    portfolioItems.toArray();
  };

  // Admin-only operation
  public shared ({ caller }) func addPortfolioItem(title : Text, category : Text, media : Storage.ExternalBlob, mediaType : Text, description : Text) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can add portfolio items");
    };
    addPortfolioItemInternal(title, category, media, mediaType, description);
  };

  // Admin-only operation
  public shared ({ caller }) func deletePortfolioItem(index : Nat) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can delete portfolio items");
    };
    deletePortfolioItemInternal(index);
  };

  // Admin-only operation
  public shared ({ caller }) func reorderPortfolioItems(moves : [ReorderPortfolioItem]) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can reorder portfolio items");
    };
    reorderPortfolioItemsInternal(moves);
  };

  // Admin-only operation
  public shared ({ caller }) func invertOrderPortfolioItem() : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can reorder portfolio items");
    };
    invertOrderPortfolioItemInternal();
  };

  // Admin-only operation
  public shared ({ caller }) func updatePortfolioItem(index : Nat, title : ?Text, category : ?Text, media : ?Storage.ExternalBlob, mediaType : ?Text, description : ?Text) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can update portfolio items");
    };
    updatePortfolioItemInternal(index, title, category, media, mediaType, description);
  };

  // Admin-only operation
  public shared ({ caller }) func movePortfolioItemToEnd(index : Nat) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can reorder portfolio items");
    };
    movePortfolioItemToEndInternal(index);
  };
};
