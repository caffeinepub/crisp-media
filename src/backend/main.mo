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

  // Stable storage for portfolio items - persists across upgrades
  stable var stablePortfolioItems : [PortfolioItem] = [];

  // Stable storage for admin state - persists across upgrades
  stable var stableAdminAssigned : Bool = false;
  stable var stableAdminPrincipals : [(Principal, AccessControl.UserRole)] = [];

  // Mutable working state, initialized from stable storage
  var portfolioItems = List.fromArray<PortfolioItem>(stablePortfolioItems);

  // Access control state, initialized from stable storage
  let accessControlState : AccessControl.AccessControlState = {
    var adminAssigned = stableAdminAssigned;
    userRoles = do {
      let m = Map.empty<Principal, AccessControl.UserRole>();
      for ((p, r) in stableAdminPrincipals.values()) { m.add(p, r) };
      m;
    };
  };

  // Persist mutable state to stable storage before upgrades
  system func preupgrade() {
    stablePortfolioItems := portfolioItems.toArray();
    stableAdminAssigned := accessControlState.adminAssigned;
    stableAdminPrincipals := accessControlState.userRoles.toArray();
  };

  // Restore mutable state from stable storage after upgrades
  system func postupgrade() {
    portfolioItems := List.fromArray<PortfolioItem>(stablePortfolioItems);
  };

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

  func deletePortfolioItemInternal(index : Nat) {
    if (index >= portfolioItems.size()) {
      Runtime.trap("Index out of bounds");
    };
    let newArray = Array.tabulate(portfolioItems.size() - 1, func(i) { if (i < index) { portfolioItems.at(i) } else { portfolioItems.at(i + 1) } });
    portfolioItems := List.fromArray(newArray);
  };

  func reorderPortfolioItemsInternal(moves : [ReorderPortfolioItem]) {
    var arr = portfolioItems.toArray();
    for (move in moves.values()) {
      if (move.originalIndex >= arr.size() or move.newIndex >= arr.size()) {
        Runtime.trap("Index out of bounds");
      };
      let item = arr[move.originalIndex];
      arr := Array.tabulate(
        arr.size() - 1,
        func(i) {
          if (i < move.originalIndex) { arr[i] } else { arr[i + 1] };
        },
      );
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

  func updatePortfolioItemInternal(index : Nat, title : ?Text, category : ?Text, media : ?Storage.ExternalBlob, mediaType : ?Text, description : ?Text) {
    if (index >= portfolioItems.size()) {
      Runtime.trap("Index out of bounds");
    };
    let item = portfolioItems.at(index);
    let updatedItem : PortfolioItem = {
      title = switch (title) { case (null) { item.title }; case (?t) { t } };
      category = switch (category) { case (null) { item.category }; case (?c) { c } };
      media = switch (media) { case (null) { item.media }; case (?m) { m } };
      mediaType = switch (mediaType) { case (null) { item.mediaType }; case (?mt) { mt } };
      createdAt = item.createdAt;
      description = switch (description) { case (null) { item.description }; case (?d) { d } };
    };
    let newArray = Array.tabulate(
      portfolioItems.size(),
      func(i) { if (i == index) { updatedItem } else { portfolioItems.at(i) } },
    );
    portfolioItems := List.fromArray(newArray);
  };

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

  public query func getPortfolioItems() : async [PortfolioItem] {
    portfolioItems.toArray();
  };

  public shared ({ caller }) func addPortfolioItem(title : Text, category : Text, media : Storage.ExternalBlob, mediaType : Text, description : Text) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can add portfolio items");
    };
    addPortfolioItemInternal(title, category, media, mediaType, description);
  };

  public shared ({ caller }) func deletePortfolioItem(index : Nat) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can delete portfolio items");
    };
    deletePortfolioItemInternal(index);
  };

  public shared ({ caller }) func reorderPortfolioItems(moves : [ReorderPortfolioItem]) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can reorder portfolio items");
    };
    reorderPortfolioItemsInternal(moves);
  };

  public shared ({ caller }) func invertOrderPortfolioItem() : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can reorder portfolio items");
    };
    invertOrderPortfolioItemInternal();
  };

  public shared ({ caller }) func updatePortfolioItem(index : Nat, title : ?Text, category : ?Text, media : ?Storage.ExternalBlob, mediaType : ?Text, description : ?Text) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can update portfolio items");
    };
    updatePortfolioItemInternal(index, title, category, media, mediaType, description);
  };

  public shared ({ caller }) func movePortfolioItemToEnd(index : Nat) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can reorder portfolio items");
    };
    movePortfolioItemToEndInternal(index);
  };
};
