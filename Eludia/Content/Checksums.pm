################################################################################

sub checksum {

	Digest::MD5::md5_hex (Dumper ($_[0]));

}

################################################################################

sub checksum_filter {

	my ($kind, $prefix, $name2def) = @_;
	
	my $hash = $preconf -> {_} -> {checksums} -> {$kind} or return ($name2def, {});

	my $needed_tables = {};
	my $new_checksums = {};

	checksum_lock ($kind);

	foreach my $key (keys %$name2def) {
	
		my $name     = $prefix . $key;
		my $def      = $name2def -> {$key};
		my $checksum;
		
		if (ref $def) {
			$checksum = checksum ($def);			
			next if $hash -> {$name} eq $checksum;
			$needed_tables -> {$key}  = Storable::dclone ($def);
		}
		else {
			$checksum = $def;
			next if $hash -> {$name} >= $checksum;
			$needed_tables -> {$key}  = $def;
		}

		$new_checksums -> {$name} = $checksum;
	
	}

	checksum_unlock ($kind);
	
	return ($needed_tables, $new_checksums);

}

################################################################################

sub checksum_write {

	my ($kind, $name2value) = @_;
	
	my $hash = $preconf -> {_} -> {checksums} -> {$kind} or return;

	checksum_lock ($kind);

	foreach my $key (keys %$name2value) {

		$hash -> {$key} = $name2value -> {$key};

	}
	
	checksum_unlock ($kind);

}

################################################################################

sub checksum_get {

	my ($kind, $name) = @_;
	
	my $hash = $preconf -> {_} -> {checksums} -> {$kind} or return undef;
	
	checksum_lock ($kind);
	
	my $value = $hash -> {$name};

	checksum_unlock ($kind);
	
	return $value;

}

################################################################################

sub checksum_set {

	my ($kind, $name, $value) = @_;
	
	my $hash = $preconf -> {_} -> {checksums} -> {$kind} or return;

	checksum_lock ($kind);

	$hash -> {$name} = $value;

	checksum_unlock ($kind);

}

################################################################################

sub get_last_update {

	my ($kind, $name) = ('last_update', '_');

	checksum_lock ($kind);

	my $value = checksum_get ($kind, $name);
	
	unless ($value) {
	
		$value = sql_select_scalar ("SELECT unix_ts FROM $conf->{systables}->{__last_update}");
		
		my $hash = $preconf -> {_} -> {checksums} -> {$kind};
		
		$hash -> {$name} = $value if $hash;
	
	}
	
	$value ||= -1;
	
	checksum_unlock ($kind);

	return $value;

}

################################################################################

sub set_last_update {

	my ($value) = @_;

	my ($kind, $name) = ('last_update', '_');
	
	checksum_lock ($kind);

	my $hash = $preconf -> {_} -> {checksums} -> {$kind};

	$hash -> {$name} = $value if $hash;
	
	sql_do ("DELETE FROM $conf->{systables}->{__last_update}");

	sql_do ("INSERT INTO $conf->{systables}->{__last_update} (unix_ts, pid) VALUES (?, ?)", $value, $$);

	checksum_unlock ($kind);

}

################################################################################

BEGIN {

	print STDERR " checksums.....................................";

	my @modules = MP2 ? ('DBM_Deep') : ('SDBM');
	
	foreach (@modules) {
	
		eval "require Eludia::Content::Checksums::$_";
		
		last if $preconf -> {_} -> {checksums};
	
	}
	
	if ($preconf -> {_} -> {checksums}) {

		print STDERR "  checksum hashes...\n";

		foreach my $kind (qw( 
		
			db_model 
			last_update 
			model_scripts 
			updates_scripts
			
		)) { 
		
			checksum_init ($kind)
			
		}

	}
	else {
	
		"DISABLED. ok.\n";
	
	}

}

1;