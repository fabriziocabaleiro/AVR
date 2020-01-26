/* LICENSE {{{ -----------------------------------------------------------------
 * IPv4 stack for AVR (ATmega8) microcontroller.
 * Copyright (C) 2020 Fabrizio Cabaleiro
 * 
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, version 2.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 * 
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <https://www.gnu.org/licenses/>.
 * ------------------------------------------------------------------------}}}*/
#ifndef _TIMER_H_
#define _TIMER_H_

/* 16bits counter, up to 18 hours with events triggering every seconds */
#define TIMER1_COUNTER_LEN             2

/* Timer counter for seconds, minutes, hours */
#define TIMER1_SECONDS_LEN             4
#define TIMER1_EVENTS_SECOND           0
#define TIMER1_EVENTS_2S               1

#endif
