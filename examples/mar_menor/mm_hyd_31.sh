#!/bin/sh
#
#------------------------------------------------------------------------
#
#    Copyright (C) 1985-2020  Georg Umgiesser
#
#    This file is part of SHYFEM.
#
#------------------------------------------------------------------------
#
#--------------------------------------------------
. ./util.sh
#--------------------------------------------------

sim=mm_hyd_31

CleanFiles $sim.ts.shy 

Run $sim

CheckFiles $sim.ts.shy
PlotMapSalt apnbath

#--------------------------------------------------

