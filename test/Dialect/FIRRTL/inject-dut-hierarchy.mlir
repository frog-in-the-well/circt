// RUN: circt-opt -pass-pipeline='firrtl.circuit(firrtl-inject-dut-hier)' -split-input-file %s | FileCheck %s

// CHECK-LABEL: firrtl.circuit "Top"
firrtl.circuit "Top" attributes {
    annotations = [{class = "sifive.enterprise.firrtl.InjectDUTHierarchyAnnotation", name = "Foo"}]
  } {
  // CHECK:      firrtl.module private @Foo()
  //
  // CHECK:      firrtl.module private @DUT
  // CHECK-SAME:   class = "sifive.enterprise.firrtl.MarkDUTAnnotation"
  //
  // CHECK-NEXT:   firrtl.instance Foo {{.+}} @Foo()
  // CHECK-NEXT: }
  firrtl.module private @DUT() attributes {annotations = [{class = "sifive.enterprise.firrtl.MarkDUTAnnotation"}]} {}

  // CHECK:      firrtl.module @Top
  // CHECK-NEXT:   firrtl.instance dut @DUT
  firrtl.module @Top() {
    firrtl.instance dut @DUT()
  }
}

// -----

// CHECK-LABEL: firrtl.circuit "NLARenaming"
firrtl.circuit "NLARenaming" attributes {
    annotations = [{class = "sifive.enterprise.firrtl.InjectDUTHierarchyAnnotation", name = "Foo"}]
  } {
  // An NLA that is rooted at the DUT moves to the wrapper.
  //
  // CHECK:      firrtl.hierpath @nla_DUTRoot [@Foo::@sub, @Sub::@a]
  firrtl.hierpath @nla_DUTRoot [@DUT::@sub, @Sub::@a]

  // NLAs that end at the DUT or a DUT port are unmodified.
  //
  // CHECK-NEXT: firrtl.hierpath @[[nla_DUTLeafModule_clone:.+]] [@NLARenaming::@dut, @DUT]
  // CHECK-NEXT: firrtl.hierpath @nla_DUTLeafModule [@NLARenaming::@dut, @DUT::@Foo, @Foo]
  // CHECK-NEXT: firrtl.hierpath @nla_DUTLeafPort [@NLARenaming::@dut, @DUT::@in]
  firrtl.hierpath @nla_DUTLeafModule [@NLARenaming::@dut, @DUT]
  firrtl.hierpath @nla_DUTLeafPort [@NLARenaming::@dut, @DUT::@in]

  // NLAs that end inside the DUT get an extra level of hierarchy.
  //
  // CHECK-NEXT: firrtl.hierpath @nla_DUTLeafWire [@NLARenaming::@dut, @DUT::@[[inst_sym:.+]], @Foo::@w]
  firrtl.hierpath @nla_DUTLeafWire [@NLARenaming::@dut, @DUT::@w]

  // An NLA that passes through the DUT gets an extra level of hierarchy.
  //
  // CHECK-NEXT: firrtl.hierpath @nla_DUTPassthrough [@NLARenaming::@dut, @DUT::@[[inst_sym:.+]], @Foo::@sub, @Sub]
  firrtl.hierpath @nla_DUTPassthrough [@NLARenaming::@dut, @DUT::@sub, @Sub]
  firrtl.module private @Sub() attributes {annotations = [{circt.nonlocal = @nla_DUTPassthrough, class = "nla_DUTPassthrough"}]} {
    %a = firrtl.wire sym @a : !firrtl.uint<1>
  }

  // CHECK:      firrtl.module private @Foo
  // CHECK:      firrtl.module private @DUT
  // CHECK-SAME:   {circt.nonlocal = @[[nla_DUTLeafModule_clone]], class = "nla_DUTLeafModule"}
  // CHECK-NEXT    firrtl.instance Foo sym @[[inst_sym]]
  firrtl.module private @DUT(
    in %in: !firrtl.uint<1> sym @in [{circt.nonlocal = @nla_DUTLeafPort, class = "nla_DUTLeafPort"}]
  ) attributes {
    annotations = [
      {class = "sifive.enterprise.firrtl.MarkDUTAnnotation"},
      {circt.nonlocal = @nla_DUTLeafModule, class = "nla_DUTLeafModule"}]}
  {
    %w = firrtl.wire sym @w {
      annotations = [
        {circt.nonlocal = @nla_DUTPassthrough, class = "nla_DUT_LeafWire"}]
    } : !firrtl.uint<1>
    firrtl.instance sub sym @sub @Sub()
  }
  firrtl.module @NLARenaming() {
    %dut_in = firrtl.instance dut sym @dut @DUT(in in: !firrtl.uint<1>)
  }
}

// -----

// CHECK-LABEL: firrtl.circuit "NLARenamingNewNLAs"
firrtl.circuit "NLARenamingNewNLAs" attributes {
    annotations = [{class = "sifive.enterprise.firrtl.InjectDUTHierarchyAnnotation", name = "Foo"}]
  } {
  // An NLA that is rooted at the DUT moves to the wrapper.
  //
  // CHECK:      firrtl.hierpath @nla_DUTRoot [@Foo::@sub, @Sub]
  // CHECK:      firrtl.hierpath @nla_DUTRootRef [@Foo::@sub, @Sub::@a]
  firrtl.hierpath @nla_DUTRoot [@DUT::@sub, @Sub]
  firrtl.hierpath @nla_DUTRootRef [@DUT::@sub, @Sub::@a]

  // NLAs that end at the DUT or a DUT port are unmodified.  These should not be
  // cloned unless they have users.
  //
  // CHECK-NEXT: firrtl.hierpath @nla_DUTLeafModule[[_:.+]] [@NLARenamingNewNLAs::@dut, @DUT]
  // CHECK-NEXT: firrtl.hierpath @nla_DUTLeafModule [@NLARenamingNewNLAs::@dut, @DUT::@Foo, @Foo]
  // CHECK-NEXT: firrtl.hierpath @[[nla_DUTLeafPort_clone:.+]] [@NLARenamingNewNLAs::@dut, @DUT]
  // CHECK-NEXT: firrtl.hierpath @nla_DUTLeafPort [@NLARenamingNewNLAs::@dut, @DUT::@Foo, @Foo]
  firrtl.hierpath @nla_DUTLeafModule [@NLARenamingNewNLAs::@dut, @DUT]
  firrtl.hierpath @nla_DUTLeafPort [@NLARenamingNewNLAs::@dut, @DUT]

  // NLAs that end at the DUT are moved to a cloned path.  NLAs that end inside
  // the DUT keep the old path symbol which gets the added hierarchy.
  //
  // CHECK-NEXT: firrtl.hierpath @nla_DUTLeafWire [@NLARenamingNewNLAs::@dut, @DUT::@[[inst_sym:.+]], @Foo]
  firrtl.hierpath @nla_DUTLeafWire [@NLARenamingNewNLAs::@dut, @DUT]

  // An NLA that passes through the DUT gets an extra level of hierarchy.
  //
  // CHECK-NEXT: firrtl.hierpath @nla_DUTPassthrough [@NLARenamingNewNLAs::@dut, @DUT::@[[inst_sym]], @Foo::@sub, @Sub]
  firrtl.hierpath @nla_DUTPassthrough [@NLARenamingNewNLAs::@dut, @DUT::@sub, @Sub]
  firrtl.module private @Sub() attributes {annotations = [{circt.nonlocal = @nla_DUTPassthrough, class = "nla_DUTPassthrough"}]} {
    %a = firrtl.wire sym @a : !firrtl.uint<1>
  }

  // CHECK:      firrtl.module private @Foo
  // CHECK-NEXT:   %w = firrtl.wire
  // CHECK-SAME:     {annotations = [{circt.nonlocal = @nla_DUTLeafWire, class = "nla_DUT_LeafWire"}]}

  // CHECK:      firrtl.module private @DUT
  // CHECK-SAME:   in %in{{.+}} [{circt.nonlocal = @[[nla_DUTLeafPort_clone]], class = "nla_DUTLeafPort"}]
  // CHECK-NEXT    firrtl.instance Foo sym @[[inst_sym]]
  firrtl.module private @DUT(
    in %in: !firrtl.uint<1> [{circt.nonlocal = @nla_DUTLeafPort, class = "nla_DUTLeafPort"}]
  ) attributes {
    annotations = [
      {class = "sifive.enterprise.firrtl.MarkDUTAnnotation"},
      {circt.nonlocal = @nla_DUTLeafModule, class = "nla_DUTLeafModule"}]}
  {
    %w = firrtl.wire {
      annotations = [
        {circt.nonlocal = @nla_DUTLeafWire, class = "nla_DUT_LeafWire"}]
    } : !firrtl.uint<1>
    firrtl.instance sub sym @sub @Sub()
  }
  firrtl.module @NLARenamingNewNLAs() {
    %dut_in = firrtl.instance dut sym @dut @DUT(in in: !firrtl.uint<1>)
  }
}
