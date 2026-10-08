# R8 / ProGuard rules for Recovery for All.
#
# HISTORY — this file used to blanket-keep the three largest dependency graphs in
# the app, and Google Play's pre-launch report answered with:
#
#     Low optimization rate (29%)
#     Low obfuscation rate (30%)
#     Low shrinking rate (30%)
#     Memory usage
#
# The lines that caused it were:
#
#     -keep class io.flutter.** { *; }
#     -keep class plugins.flutter.io.** { *; }
#     -keep class com.google.firebase.** { *; }
#     -keep class com.google.android.gms.** { *; }
#
# `-keep ... { *; }` means "keep every class AND every member, never rename, never
# remove", so those four lines disabled shrinking, renaming and optimization for
# the entire Flutter embedding, the entire Firebase SDK and the entire Play
# Services SDK. They were also redundant: Flutter's Gradle plugin, the Firebase
# BoM and Play Services all ship their own consumer ProGuard/R8 rules, which AGP
# merges automatically. The official Flutter release template ships this file
# essentially empty for exactly that reason.
#
# Removing them is not free — a class reached only by reflection will still be
# stripped, and that fails at RUNTIME on a release build, never at build time.
# So the removal was verified on a real device before shipping: app launch, boot
# log, notification initialization and the notification resource in the compiled
# resource table. See SESSION_HANDOFF.md.
#
# If a release-only crash appears that retrace cannot explain, the fix is to add
# back ONE narrow rule for the class in question, never a blanket for a whole
# tree. Reintroducing a `-keep class <package>.** { *; }` here silently undoes the
# entire optimization.

# No -keep rules are required. Flutter (io.flutter.**, plugins.flutter.io.**),
# Firebase (com.google.firebase.**) and Play Services (com.google.android.gms.**)
# all ship consumer rules that are merged with this file.

# Keep suppressions only. `-dontwarn` stops R8 failing the build over optional
# references it cannot resolve in the engine and in the Firebase SDK; it does not
# affect shrinking or obfuscation.
-dontwarn io.flutter.embedding.**
-dontwarn com.google.firebase.**
