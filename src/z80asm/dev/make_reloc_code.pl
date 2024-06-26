#!/usr/bin/env perl

use Modern::Perl;
use CPU::Z80::Assembler;
use Path::Tiny;

my $bin = z80asm_file('reloc_code.asm');
my $bin_size = length($bin);
my $bin_hex = "";
my $n = 0;
for (split //, $bin) {
	$bin_hex .= sprintf("0x%02X,", ord($_));
	if (++$n >= 16) {
		$bin_hex .= "\n";
		$n = 0;
	}
}

open(my $fh, ">", "reloc_code.h") or die $!;
print $fh <<END;
// generated by $0
#pragma once
#include <stddef.h>
#include <stdint.h>

extern size_t sizeof_relocroutine;
extern const uint8_t reloc_routine[];
END

open($fh, ">", "reloc_code.c") or die $!;
print $fh <<END;
// generated by $0
#include "reloc_code.h"

size_t sizeof_relocroutine = $bin_size;
const uint8_t reloc_routine[$bin_size] = {
$bin_hex
};
END
