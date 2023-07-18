export default function GeneralLayout(children) {
    return(
        <View style={componentStyles}>
            {children}
        </View>
    );
}

const componentStyles = StyleSheet.create({
    container: {
        display: 'flex',
        flexDirection: "column",
        alignItems: 'center',
        justifyContent: 'center',
    },
});