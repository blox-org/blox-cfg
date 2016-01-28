#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/inotify.h>
#include <string.h>


#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <fcntl.h>



#define EVENT_SIZE  ( sizeof (struct inotify_event) )
#define BUF_LEN	 ( 1024 * ( EVENT_SIZE + 16 ) )

#define MAX_WATCHER (1024)
#define MAX_PATH    (1024*2)

static int wfd;
static int wi = 0;
static int init = 0;

struct inotify_list {
	int wd;
	char dirname[MAX_PATH];
} notifies[MAX_WATCHER] ;


#define WATCH_FLAGS (IN_CREATE)

int is_dir(const char *file)
{
	struct stat st;
	return ((stat(file,&st)==0) && S_ISDIR(st.st_mode) && !S_ISLNK( st.st_mode )) ;
}

int notifies_index_from_wd(int wd)
{
	int i;
	for(i=0;i<wi;i++) {
		if(notifies[i].wd==wd) {
			return i ;
		}
	}
	return -1;
}

static int is_inotify_added_watch(const char *file)
{
	int i = 0;
	for(i=0;i<wi;i++) {
		if(strcmp(notifies[i].dirname,file)==0) {
			return 1;	
		}
	}
	return 0;
}

#define ERROR (-2)
#define ALREADY_ADDED (-1)
#define NEWLY_ADDED   (0)

static int _inotify_add_watch(const char *file)
{
	if(!is_dir(file)) {
		fprintf(stderr, "_inotify_add_watch: not a directory %s\n", file);
		return ERROR;
	}

	if(is_inotify_added_watch(file)) { //Already added to watch
		fprintf(stderr, "_inotify_add_watch: already watching %s\n", file);
		return ALREADY_ADDED;
	}

	//printf( "Adding directory %s to watch list.\n", file);
	notifies[wi].wd = inotify_add_watch(wfd, file, WATCH_FLAGS);
	strncpy(notifies[wi].dirname,file,MAX_PATH);
	if(notifies[wi].wd < 0) {
		perror("inotify_add_watch");
		return ERROR;
	}

	wi++ ;
	return NEWLY_ADDED ;
}

void inotify_add_watch_dirwalk(char *dir)
{
	char name[MAX_PATH];
	struct dirent *dp;
	DIR *dfd;

	//printf( "AM HERE :%s:%d:\n", __func__, __LINE__ ) ;

	if ((dfd = opendir(dir)) == NULL) {
		fprintf(stderr, "inotify_add_watch_dirwalk: can't open %s\n", dir);
		return;
	}

	while ((dp = readdir(dfd)) != NULL) {
		if (strcmp(dp->d_name, ".") == 0
				|| strcmp(dp->d_name, "..") == 0)
			continue;
		if (strlen(dir)+strlen(dp->d_name)+2 > sizeof(name))
			fprintf(stderr, "dirwalk: name %s/%s too long\n",
					dir, dp->d_name);
		else {
			sprintf(name, "%s/%s", dir, dp->d_name);
			if(is_dir(name)) {
				if(_inotify_add_watch(name) == NEWLY_ADDED) {
					if(init) fprintf( stdout, "CREATED DIR %s\n", name );
					inotify_add_watch_dirwalk(name);
				}
			} else {
				if(init) fprintf( stdout, "CREATED FILE %s\n", name );
			}
		}
	}
	closedir(dfd);
}

int main( int argc, char **argv ) 
{
	int length, i = 0;
	char buffer[BUF_LEN];
	char *watch_dir ;


	if(argc != 2) {
		fprintf(stderr, "usage: %s <monitor_dir_path>\n", argv[0]);
		return -1;
	}

	watch_dir = argv[1] ;
	if(!is_dir(watch_dir)) {
		fprintf(stderr, "%s not directory\n", argv[1]);
		fprintf(stderr, "usage: %s <monitor_dir_path>\n", argv[0]);
		return -1;
	}

	wfd = inotify_init();

	if ( wfd < 0 ) {
		perror( "inotify_init" );
		return -1;
	}

	
#if 0
	int stdout_fd = fileno(stdout) ;
	int flags = fcntl(stdout_fd, F_GETFL);
	fcntl(stdout_fd, F_SETFL, flags | O_NONBLOCK | O_DIRECT | O_SYNC);
#else
	setbuf(stdout, NULL);
#endif

	_inotify_add_watch(watch_dir);
	inotify_add_watch_dirwalk(watch_dir);

	init = 1;

	while(1) {
		struct inotify_event *event;

		length = read( wfd, buffer, BUF_LEN );  

		if ( length < 0 ) {
			perror( "read" );
		} 

		event = ( struct inotify_event * ) &buffer[ i ];

		if ( event->len ) {
			//printf("GOT EVENT in %s %d\n", watch_dir, event->mask );
			if((event->mask & IN_CREATE)) {
				char name[MAX_PATH] ;
				int twi ;
				if ( event->mask & IN_ISDIR ) {
					if((twi=notifies_index_from_wd(event->wd))>=0) {
						snprintf(name,MAX_PATH,"%s/%s",notifies[twi].dirname,event->name) ;
					} else {
						snprintf(name,MAX_PATH,"%s",event->name) ;
					}
					if(is_dir(name)) {
						if(_inotify_add_watch(name) == NEWLY_ADDED) {
							if(init) fprintf( stdout, "CREATED DIR %s\n", name );
							inotify_add_watch_dirwalk(name);
						}
					}
				} else {
					if((twi=notifies_index_from_wd(event->wd))>=0) {
						snprintf(name,MAX_PATH,"%s/%s",notifies[twi].dirname,event->name) ;
					} else {
						snprintf(name,MAX_PATH,"%s",event->name) ;
					}
					if(init) fprintf( stdout, "CREATED FILE %s\n", name );
				}
			}
		}
	}

	for(;wi>=0;wi--) {
		( void ) inotify_rm_watch( wfd, notifies[wi].wd );
	}

	( void ) close( wfd );

	exit( 0 );
}
